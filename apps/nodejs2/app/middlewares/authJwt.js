const jwt = require("jsonwebtoken");
const config = require("../config/auth.config.js");
const db = require("../models");
const User = db.user;
const Role = db.role;

// This function checks the user sent the token and it is valid. The token is generated and validated using jwt framework.
verifyToken = (req, res, next) => {
  let token = req.headers["x-access-token"];
  console.log ('token' + token);
  if (!token) {
    return res.status(403).send({ message: "No token provided!" });
  }

  jwt.verify(token, config.secret, (err, decoded) => {
    if (err) {
      return res.status(401).send({ message: "Unauthorized!" });
    }
    req.userId = decoded.id;
    next();
  });
};

// This function checks if the user is admin, if yes, it sends the message that user has admin role.
isAdmin = (req, res, next) => {
  User.findById(req.userId).exec((err, user) => {
    if (err) {
      res.status(500).send({ message: err });
      return;
    }

    Role.find(
      {
        _id: { $in: user.roles }
      },
      (err, roles) => {
        if (err) {
          res.status(500).send({ message: err });
          return;
        }

        for (let i = 0; i < roles.length; i++) {
          if (roles[i].name === "admin") {
            next();
            return;
          }
        }

        res.status(403).send({ message: "Require Admin Role!" });
        return;
      }
    );
  });
};


// This function checks if the user is moderator, if yes, it sends the message that user has moderator role.
isModerator = (req, res, next) => {
  User.findById(req.userId).exec((err, user) => {
    if (err) {
      res.status(500).send({ message: err });
      return;
    }

    Role.find(
      {
        _id: { $in: user.roles }
      },
      (err, roles) => {
        if (err) {
          res.status(500).send({ message: err });
          return;
        }

        for (let i = 0; i < roles.length; i++) {
          if (roles[i].name === "moderator") {
            next();
            return;
          }
        }

        res.status(403).send({ message: "Require Moderator Role!" });
        return;
      }
    );
  });
};

// This fuction checks if the user has a valid session. If not, the user is not authorized. The session is being set when
// the user logs in
authMiddleware = (req,res, next) => {
  console.log('session in authMiddleware:' + JSON.stringify(req.session));
  console.log('sid in authMiddleware:' + req.session.id);
 // console.log('sid in authMiddleware:' + req.sessionID);
  
  console.log('email in authMiddleware:' + req.session.email);

  if (  req.session.email)
   {
     console.log('you are authenticated and have right session')
     next();
   }
   else
   {
     res.status(403).send(
       {message :'You must be logged in!'}
     )
   }

};

const authJwt = {
  verifyToken,
  isAdmin,
  isModerator,
  authMiddleware
};
module.exports = authJwt;