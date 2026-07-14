const { verifySignUp, authGoogle, authJwt } = require("../middlewares");
const controller = require("../controllers/auth.controller");

module.exports = function(app) {
  app.use(function(req, res, next) {
    res.header(
      "Access-Control-Allow-Headers",
      "x-access-token, Origin, Content-Type, Accept"
    );
    next();
  });

  app.post(
    "/api/auth/signup",
    [
      verifySignUp.checkDuplicateUsernameOrEmail,
      verifySignUp.checkRolesExisted
    ],
    controller.signup
  );

  app.post("/api/auth/signin", controller.signin);
 // app.post("/api/auth/setsession", controller.setsession);
  app.post("/api/auth/signout", [authJwt.authMiddleware] , controller.signout);

  app.post("/api/auth/tokensignin",  [authGoogle.verifyGoogleToken ] , 
      controller.tokensignin
   
   );

   
   app.post("/api/auth/req-reset-password", controller.resetpassword);
   app.post("/api/auth/new-password", controller.newpassword);
   app.post("/api/auth/valid-password-token", controller.validpasswordtoken);



  
};