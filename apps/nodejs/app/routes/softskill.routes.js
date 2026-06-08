const controller = require("../controllers/softskill.controller");
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

  //app.get("/api/test/getSoftSkills", [authJwt.authMiddleware], controller.getSoftSkills);
  app.get("/api/test/getSoftSkills", [keycloak.protect('user')], controller.getSoftSkills);
  app.put("/api/test/updateSoftSkills/:id", [keycloak.protect('admin')],controller.updateSoftSkills);
  app.post("/api/test/createSoftSkills",[keycloak.protect('admin')], controller.createSoftSkills);
  app.delete("/api/test/deleteSoftSkills/:id", [keycloak.protect('admin')],controller.deleteSoftSkills);
  
};