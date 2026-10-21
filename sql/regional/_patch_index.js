const fs = require("fs");
const path = require("path");

const indexPath = "D:/BODO/KANTOR/REACT/POS_React/src/route/Index.js";
const imports = fs.readFileSync(
  path.join(__dirname, "_react_imports.txt"),
  "utf8"
);
const routes = fs.readFileSync(
  path.join(__dirname, "_react_routes.txt"),
  "utf8"
);

let src = fs.readFileSync(indexPath, "utf8");

if (!src.includes("pages/admin/regional/pages")) {
  src = src.replace(
    '} from "../pages/admin/hrd/pages";\n',
    '} from "../pages/admin/hrd/pages";\n' + imports
  );
}

if (!src.includes('path="regional/dashboard"')) {
  src = src.replace(
    '            <Route path="hrd/cab/payment-request" element={<HrdCabPaymentPage />} />\n          </Route>',
    '            <Route path="hrd/cab/payment-request" element={<HrdCabPaymentPage />} />\n' +
      routes +
      "\n          </Route>"
  );
}

fs.writeFileSync(indexPath, src);
console.log("Index.js patched");
