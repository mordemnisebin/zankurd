-- GERİ ALMA: 2026-11-09_xew_sik.sql
begin;

update questions
   set option_c = 'nivistina mirovan'
 where id = '75c2140f-7d76-5625-9dc6-d256096a5783'
   and option_c = 'razana mirovan'
   and correct_option = 'C';

commit;
