"""End-to-end live Supabase check for ZanKurd multiplayer.

This script uses only the public publishable key, like the mobile app.
It creates two anonymous users, creates a room as user A, joins by room code as
user B, starts the game, submits one answer from both users, and checks the
leaderboard.
"""

from __future__ import annotations

import json
import random
import string
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


BASE_URL = "https://hupivnxgjtsfafulzspo.supabase.co"
PUBLISHABLE_KEY = "sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s"


class CheckFailed(RuntimeError):
    pass


@dataclass(frozen=True)
class UserSession:
    access_token: str
    user_id: str
    name: str


def request(
    method: str,
    path: str,
    *,
    token: str | None = None,
    body: dict[str, Any] | None = None,
    prefer: str | None = None,
) -> tuple[int, Any]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {
        "apikey": PUBLISHABLE_KEY,
        "Authorization": f"Bearer {token or PUBLISHABLE_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer

    req = urllib.request.Request(
        BASE_URL + path,
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as response:
            text = response.read().decode("utf-8")
            return response.status, json.loads(text) if text else None
    except urllib.error.HTTPError as error:
        text = error.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(text) if text else None
        except json.JSONDecodeError:
            parsed = text
        return error.code, parsed


def expect_ok(label: str, status: int, data: Any, allowed: set[int]) -> Any:
    if status not in allowed:
        raise CheckFailed(f"{label} failed: HTTP {status}: {data}")
    return data


def create_anonymous_user(name: str) -> UserSession:
    status, data = request(
        "POST",
        "/auth/v1/signup",
        body={"data": {"display_name": name}},
    )
    expect_ok("anonymous sign-in", status, data, {200})
    return UserSession(
        access_token=data["access_token"],
        user_id=data["user"]["id"],
        name=name,
    )


def ensure_profile(session: UserSession) -> None:
    status, data = request(
        "POST",
        "/rest/v1/profiles?on_conflict=id",
        token=session.access_token,
        prefer="resolution=merge-duplicates,return=representation",
        body={
            "id": session.user_id,
            "display_name": session.name,
            "avatar_color": "#E94560",
        },
    )
    expect_ok("profile upsert", status, data, {200, 201})


def load_ziman_category_id(token: str) -> str:
    status, data = request(
        "GET",
        "/rest/v1/categories?select=id,name&name=eq.Ziman&limit=1",
        token=token,
    )
    expect_ok("load Ziman category", status, data, {200})
    if not data:
        raise CheckFailed("Ziman category is missing")
    return data[0]["id"]


def create_room(host: UserSession, category_id: str) -> tuple[str, str]:
    code = "ZT" + "".join(
        random.choice(string.ascii_uppercase + string.digits) for _ in range(4)
    )
    status, data = request(
        "POST",
        "/rest/v1/rooms?select=id,code,question_count,status",
        token=host.access_token,
        prefer="return=representation",
        body={
            "code": code,
            "host_id": host.user_id,
            "category_id": category_id,
            "question_count": 10,
            "seconds_per_question": 15,
        },
    )
    expect_ok("room create", status, data, {200, 201})
    room = data[0]
    status, data = request(
        "POST",
        "/rest/v1/room_players",
        token=host.access_token,
        prefer="return=representation",
        body={"room_id": room["id"], "player_id": host.user_id, "is_ready": True},
    )
    expect_ok("host room membership", status, data, {200, 201})
    return room["id"], room["code"]


def join_room_by_code(player: UserSession, code: str) -> str:
    status, data = request(
        "POST",
        "/rest/v1/rpc/join_room_by_code",
        token=player.access_token,
        body={"p_code": code},
    )
    expect_ok("join_room_by_code RPC", status, data, {200})
    return data["room_id"]


def load_players(token: str, room_id: str) -> list[dict[str, Any]]:
    status, data = request(
        "GET",
        "/rest/v1/room_players"
        "?select=player_id,score,streak,is_ready,profiles(display_name)"
        f"&room_id=eq.{room_id}&order=joined_at",
        token=token,
    )
    expect_ok("load room players", status, data, {200})
    return data


def start_game(host: UserSession, room_id: str) -> None:
    status, data = request(
        "POST",
        "/rest/v1/rpc/start_room_game",
        token=host.access_token,
        body={"p_room_id": room_id},
    )
    expect_ok("start_room_game RPC", status, data, {200})


def load_first_room_question(token: str, room_id: str) -> tuple[str, str]:
    status, data = request(
        "GET",
        "/rest/v1/room_questions"
        "?select=question_index,question_id,"
        "questions(id,prompt,correct_option,option_a,option_b,option_c,option_d)"
        f"&room_id=eq.{room_id}&order=question_index&limit=1",
        token=token,
    )
    expect_ok("load room question", status, data, {200})
    if not data:
        raise CheckFailed("start_room_game did not create room questions")
    question = data[0]["questions"]
    return question["id"], question["correct_option"]


def submit_answer(session: UserSession, room_id: str, question_id: str, option: str) -> None:
    status, data = request(
        "POST",
        "/rest/v1/rpc/submit_answer",
        token=session.access_token,
        body={
            "p_room_id": room_id,
            "p_question_id": question_id,
            "p_selected_option": option,
            "p_response_ms": 1000,
        },
    )
    expect_ok("submit_answer RPC", status, data, {200})
    if data.get("new_score", 0) <= 0 and data.get("points", 0) <= 0:
        raise CheckFailed(f"answer did not award points: {data}")


def finish_game(session: UserSession, room_id: str) -> None:
    status, data = request(
        "POST",
        "/rest/v1/rpc/finish_room_game",
        token=session.access_token,
        body={"p_room_id": room_id},
    )
    expect_ok("finish_room_game RPC", status, data, {200})


def assert_leaderboard_contains(user_ids: set[str]) -> None:
    encoded_ids = ",".join(sorted(user_ids))
    status, data = request(
        "GET",
        "/rest/v1/leaderboard_entries"
        "?select=player_id,display_name,total_score,best_streak,rooms_played"
        f"&player_id=in.({encoded_ids})",
    )
    expect_ok("leaderboard load", status, data, {200})
    seen = {row["player_id"] for row in data}
    missing = user_ids - seen
    if missing:
        raise CheckFailed(f"leaderboard is missing players: {sorted(missing)}")


def main() -> int:
    try:
        suffix = "".join(random.choice(string.digits) for _ in range(4))
        user_a = create_anonymous_user(f"Codex Canli A {suffix}")
        user_b = create_anonymous_user(f"Codex Canli B {suffix}")
        ensure_profile(user_a)
        ensure_profile(user_b)

        category_id = load_ziman_category_id(user_a.access_token)
        room_id, code = create_room(user_a, category_id)
        joined_room_id = join_room_by_code(user_b, code)
        if joined_room_id != room_id:
            raise CheckFailed(f"joined wrong room: {joined_room_id} != {room_id}")

        players = load_players(user_a.access_token, room_id)
        if {row["player_id"] for row in players} != {user_a.user_id, user_b.user_id}:
            raise CheckFailed(f"room players are wrong: {players}")

        start_game(user_a, room_id)
        question_id, correct_option = load_first_room_question(user_a.access_token, room_id)
        submit_answer(user_a, room_id, question_id, correct_option)
        submit_answer(user_b, room_id, question_id, correct_option)
        finish_game(user_a, room_id)
        assert_leaderboard_contains({user_a.user_id, user_b.user_id})

        print(
            json.dumps(
                {
                    "ok": True,
                    "room_code": code,
                    "room_id": room_id,
                    "players": [user_a.name, user_b.name],
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0
    except CheckFailed as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False, indent=2))
        return 1


if __name__ == "__main__":
    sys.exit(main())
