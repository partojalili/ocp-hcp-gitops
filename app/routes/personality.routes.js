const controller = require("../controllers/personality.controller");
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

 // app.get("/api/test/getPers", [authJwt.authMiddleware], controller.getPers);
  app.get("/api/test/getPers", [keycloak.protect('user')], controller.getPers);
  app.put("/api/test/updatePers/:id", [keycloak.protect('admin')],controller.updatePers);
  app.post("/api/test/createPers",[keycloak.protect('admin')], controller.createPers);
  app.delete("/api/test/deletePers/:id", [keycloak.protect('admin')],controller.deletePers);
  
};