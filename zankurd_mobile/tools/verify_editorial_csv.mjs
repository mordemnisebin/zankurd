import fs from "node:fs/promises";
import { Workbook } from "@oai/artifact-tool";

const csvPath = process.argv[2];
const csvText = await fs.readFile(csvPath, "utf8");
const workbook = await Workbook.fromCSV(csvText, { sheetName: "AI Review" });
const inspect = await workbook.inspect({
  kind: "table",
  range: "AI Review!A1:Q6",
  include: "values",
  tableMaxRows: 6,
  tableMaxCols: 17,
  maxChars: 5000,
});
console.log(inspect.ndjson);
