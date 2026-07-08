
const db = require("../models");
const User = db.user;
const Role = db.role;
const config = require("../config/auth.config");
const crypto = require('crypto');
var jwt = require("jsonwebtoken");
const keycloak = require('../config/keycloak-config.js').getKeycloak();

var bcrypt = require("bcryptjs");
const { data } = require("jquery");

exports.allAccess = (req, res) => {
    
  res.status(200).send("Public Data.");
  };

  
  exports.userBoard = (req, res) => {
    console.log('keycloak authorization is this:' + req.headers.authorization.split(' ')[1] );
    var token=req.headers.authorization.split(' ')[1];
    obj = jwt.decode(token );
   // const decodedToken = jwt.decode(token, { complete: true });


   // console.log('this is decoded token' + decodedToken);
    console.log('First name and last name:' + obj.name);
    console.log('Username:' + obj.preferred_username);
    console.log('resource_access:' + JSON.stringify(obj));
    

    res.status(200).send(JSON.stringify(obj));
   
  };
  
  // exports.userBoard = (req, res) => {
  //   res.status(200).send("User Content.: " + req.kauth.grant);
  // };

  

//   app.get('/api/test/user', keycloak.enforcer('user:profile', {response_mode: 'token'}), function (req, res) {
//     ​let  tokenDetails = req.kauth.grant.access_token.content;

// ​});

  exports.adminBoard = (req, res) => {
    res.status(200).send("Admin Content.");
  };
  
  exports.moderatorBoard = (req, res) => {
    res.status(200).send("Moderator Content.");
  };

  exports.getUserStatus = async (req, res) => {
    console.log('session in getUserStatus:' + JSON.stringify(req.session));
    console.log('sid in getUserStatus:' + req.session.id);

    console.log ('user name in getuserstatus:' + JSON.stringify(req.body.user));
    res.status(200).send({
    
      user: req.body.user
    });
  }

  exports.getUserRole = async (req, res) => {
    console.log('session in getUserRole:' + JSON.stringify(req.session));
    console.log('sid in getUserRole:' + req.session.id);

    console.log ('user  in getUserRole:' + JSON.stringify(req.body.user));

    const user= await User.findOne({
      id: req.user
    })
      .populate("roles", "-__v")
      .exec((err, user) => {
        if (err) {
         
          res.status(500).send({ message: err });
          return;
        }  
      if (!user) {
        
        return res.status(404).send({ message: "User Not found!" });
      }
      
      var authorities = [];

      for (let i = 0; i < user.roles.length; i++) {
        authorities.push("ROLE_" + user.roles[i].name.toUpperCase());
      }
      console.log ('authorities' + authorities);


    res.status(200).send({
    
        userId: user._id,
        roles: authorities
       
    });
  });

  }


  exports.getUserProfile = async (req, res) => {
    console.log('keycloak authorization is this:' + req.headers.authorization.split(' ')[1] );
    var token=req.headers.authorization.split(' ')[1];
    obj = jwt.decode(token );
  
   
    console.log('Username:' + obj.preferred_username);
    console.log('resource_access:' + JSON.stringify(obj));

    console.log ('user name in getUserProfile:' + JSON.stringify(obj.preferred_username));

    const user= await User.findOne({
     // email: req.body.user
     username: obj.preferred_username
    }, function(err, user){

    
      if (err) {
        res.status(500).send({ message: err });
       
        return;
      }
      if (!user) {
        req.session.email="null";
        return res.status(404).send({ message: "User Not found!" });
      }
      
      console.log('user from mongodb is:' + JSON.stringify(user));
      res.status(200).send({
       

        userId: user._id,
        username: user.username,
        firstname: user.firstname,
        lastname: user.lastname,
        email: user.email,
        address:{
        street: user.address.street,
        city: user.address.city,
        state: user.address.state,
        zipcode: user.address.zipcode},
       // roles: authorities,
       // accessToken: token,
       IsGoogleUser: user.IsGoogleUser
       
      });
   
   
  });
}

exports.updateProfile =  async (req, res) => {
 console.log('In updateProfile: ' + JSON.stringify(req.body));
 const user = await User.findOne(
   {email: req.body.email}, function (err, user) {
      user.firstname = req.body.firstname,
      user.lastname = req.body.lastname,
      user.email = req.body.email,
      user.address= {
      street: req.body.address.street,
      city: req.body.address.city,
      state: req.body.address.state,
      zipcode: req.body.address.zipcode};
      if(err){
        console.error('ERROR!');
        res.status(500).send({ message: err });
      }
  
      user.save(function (err) {
        if(err) {
            console.error('ERROR!');
            res.status(500).send({ message: err }); 
        }
      });
  });

 res.status(200).send({
   email: req.body.email,
   message: "User profile updated successfully."
 
});
  
};