const { authJwt } = require("../middlewares");
const controller = require("../controllers/user.controller");
const keycloak = require('../config/keycloak-config.js').getKeycloak();
//const jwt = require('jsonwebtoken');
//var tokendetails = jwt.decode(token);

module.exports = function(app) {
  app.use(function(req, res, next) {
    res.header(
      "Access-Control-Allow-Headers",
      "x-access-token, Origin, Content-Type, Accept"
    );
    next();
  });

//  app.get("/api/test/all", controller.allAccess);

  //app.get("/api/test/user", [authJwt.authMiddleware],  controller.userBoard);
  app.get('/api/test/all',  controller.allAccess);

 app.get("/api/test/user",  [keycloak.protect('user')],  controller.userBoard);
// app.get("/api/test/user",    controller.userBoard);
   
//  app.get('/api/test/user', keycloak.enforcer('user:profile', {response_mode: 'token'}), function (req, res) {
//   ​var token = req.kauth.grant.access_token.content;
// //  ​var permissions = token.authorization ? token.authorization.permissions : undefined;

//   ​// show user profile
// ​});


  // app.get(
  //   "/api/test/mod",
  //   [authJwt.verifyToken, authJwt.isModerator],
  //   controller.moderatorBoard
  // );

  // app.get(
  //   "/api/test/admin",
  //   [authJwt.verifyToken, authJwt.isAdmin],
  //   controller.adminBoard
  // );

  app.post(
    "/api/test/getuserstatus", [keycloak.protect('user')], controller.getUserStatus);

    app.post(
      "/api/test/getuserrole", [keycloak.protect('user')], controller.getUserRole);

    app.post(
      "/api/test/getuserprofile", [keycloak.protect('user')], controller.getUserProfile);
    
      app.post(
        "/api/test/updateProfile", [keycloak.protect('user')], controller.updateProfile);



  


   // app.use( keycloak.middleware( { logout: '/'} ));
      
};