const controller = require("../controllers/hardskill.controller");
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

 // app.get("/api/test/getHardSkills", [authJwt.authMiddleware], controller.getHardSkills);
  app.get("/api/test/getHardSkills", [keycloak.protect('user')], controller.getHardSkills);
  app.put("/api/test/updateHardSkills/:id", [keycloak.protect('admin')], controller.updateHardSkills);
  app.post("/api/test/createHardSkills",[keycloak.protect('admin')], controller.createHardSkills);
  app.delete("/api/test/deleteHardSkills/:id", [keycloak.protect('admin')],controller.deleteHardSkills);
};