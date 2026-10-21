const fs = require("fs");
const path = require("path");
const dir = __dirname;
const m = require("./_pages_meta.json");

const lines = [
  "func RegisterRegionalRoutes(router *mux.Router) {",
  '\treg := router.PathPrefix("/api/v1").Subrouter()',
  "\treg.Use(middleware.RbcaJWTMiddleware)",
  "\treg.Use(controllers.RbcaBodyParser)",
  '\treg.HandleFunc("/regional/lookups/{type}", controllers.RegionalLookupHandler).Methods("GET")',
  '\treg.HandleFunc("/regional/dashboard/summary", controllers.RegionalDashboardSummary).Methods("GET")',
  "",
];

for (const p of m) {
  lines.push(
    `\tcontrollers.RegisterRegionalEntityRoutes(reg, "${p.path}", "${p.entity}", ${p.crud})`
  );
}
lines.push("}");

fs.writeFileSync(path.join(dir, "_register_routes.go.txt"), lines.join("\n"));

// React route JSX
const reactLines = [];
reactLines.push('            <Route path="regional/dashboard" element={<RegDashboardPage />} />');
for (const p of m) {
  reactLines.push(
    `            <Route path="regional/${p.path}" element={<${p.exportName} />} />`
  );
}
fs.writeFileSync(path.join(dir, "_react_routes.txt"), reactLines.join("\n"));

const importNames = ["RegDashboardPage", ...m.map((p) => p.exportName)];
fs.writeFileSync(
  path.join(dir, "_react_imports.txt"),
  `import {\n  ${importNames.join(",\n  ")}\n} from "../pages/admin/regional/pages";\n`
);

console.log("routes", m.length);
