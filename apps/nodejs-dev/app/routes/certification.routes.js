const controller = require("../controllers/certifications.controller");
const { authJwt } = require("../middlewares");
const keycloak = require('../config/keycloak-config.js').getKeycloak();


module.exports = function(app) {
  app.use(function(req, res, next) {
    res.header(
      "Access-Control-Allow-Headers",
      "x-access-token, Origin, Content-Type, Accept"
    );
    next();
  });

 //
 //[keycloak.protect('user')]
 app.get("/api/test/getCerts", [keycloak.protect('user')], controller.getCerts);
// app.get("/api/test/getCerts",  controller.getCerts);
// app.get("/api/test/getCerts", [authJwt.authMiddleware], controller.getCerts);
  app.put("/api/test/updateCert/:id", [keycloak.protect('admin')], controller.updateCert);
  app.post("/api/test/createCert", [keycloak.protect('admin')], controller.createCert);
  app.delete("/api/test/deleteCert/:id", [keycloak.protect('admin')], controller.deleteCert);
  
};