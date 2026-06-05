const config = require("../config/auth.config");
const crypto = require('crypto');

const nodemailer = require('nodemailer');
const { google } = require("googleapis");
const OAuth2 = google.auth.OAuth2;

const db = require("../models");
const User = db.user;
const Role = db.role;
const Session = db.session;
const PasswordResetToken = db.resettoken;


var jwt = require("jsonwebtoken");
var bcrypt = require("bcryptjs");

exports.signup = async (req, res) => {
  console.log('I am here in signup');
  const user =  await User({
    username: req.body.username,
    email: req.body.email,
    password: bcrypt.hashSync(req.body.password, 8),
    IsGoogleUser: req.body.IsGoogleUser,
  }, function (err, user){
    if (err){
      console.error('ERROR!');
      res.status(500).send({ message: err });
    }

  });
   console.log(JSON.stringify(user));
   user.save((err, user) => {
    if (err) {
        res.status(499).send({ message: err + '0' });
      return;
    }

    if (req.body.roles) {
     Role.find(
        {
          name: { $in: req.body.roles }
        },
        function (err, roles)  {
          if (err) {
             res.status(501).send({ message: err + '1' });
            return;
          }

          user.roles = roles.map(role => role._id);
          user.save(err => {
            if (err) {
               res.status(502).send({ message: err +'2'});
              return;
            }

            res.send({ message: "User was registered successfully!" });
          });
        }
      );
    } else {
       Role.findOne({ name: "user" }, function(err, role)  {
        if (err) {
           res.status(503).send({ message: err + '3'});
          return;
        }

        user.roles = [role._id];
        user.save(err => {
          if (err) {
             res.status(504).send({ message: err + '4' });
            return;
          }

          res.send({ message: "User was registered successfully!" });
        });
      });
    }
  });
};

exports.signin = async (req, res) => {
  //console.log ('session in sign in before setting email:' + JSON.stringify(req.body));

  User.findOne({
    username: req.body.username, IsGoogleUser:'N'
  })
    .populate("roles", "-__v")
    .exec((err, user) => {
      if (err) {
        req.session.email="null";
        res.status(500).send({ message: err });
        return;
      }

      if (!user) {
        req.session.email="null";
        return res.status(404).send({ message: "User Not found!" });
      }

      var passwordIsValid = bcrypt.compareSync(
        req.body.password,
        user.password
      );

      if (!passwordIsValid) {
        req.session.email="null";
        return res.status(401).send({
          accessToken: null,
          message: "Invalid Password!"
        });
       
      }
      
         var token = jwt.sign({ id: user.id }, config.secret, {
        expiresIn: 86400 // 24 hours
      });

      var authorities = [];

      for (let i = 0; i < user.roles.length; i++) {
        authorities.push("ROLE_" + user.roles[i].name.toUpperCase());
      }
    
      req.session.email=user.email;
   
      console.log('user email is :' + user.email);
      console.log('session in signin after setting email in cookies:' + JSON.stringify(req.session));
   
      res.status(200).send({
       

        userId: user._id,
        firstname: user.GivenName,
        lastname: user.FamilyName,
        username: user.username,
        email: user.email,
        roles: authorities,
        accessToken: token,
       
      });
    });
};


exports.tokensignin = async (req, res) =>{
  console.log('we are in tokensignin');
  console.log('sid in tokensignin before setting:' + req.session.id);
  console.log('session in tokensignin before setting:' + JSON.stringify(req.session));
  console.log('user in tokensignin before setting:' + JSON.stringify(req.body));
//  console.log('Google token in tokensignin' + req.body.id_token);
  const user = await User({
    username: req.body.Name,
    firstname: req.body.GivenName,
    lastname: req.body.FamilyName,
    email: req.body.Email,
    password: bcrypt.hashSync(req.body.password, 8),
    IsGoogleUser: req.body.IsGoogleUser,
  });
 // console.log('user in tokensignin' + JSON.stringify(user));
   User.findOne({
    email: req.body.Email, IsGoogleUser:'Y'
  }, function (err, user)
     {
      if (err) {
         req.session.email="null";
        res.status(500).send({ message: err });
        return;
      }
      if (!user){   // user not found
      
        user = new User ({
        username: req.body.username,
        firstname: req.body.GivenName,
        lastname: req.body.FamilyName,
        email: req.body.Email,
        password: bcrypt.hashSync(req.body.password, 8),
        IsGoogleUser: req.body.IsGoogleUser,
      });
    
      user.save((err, user) => {
        if (err) {
          req.session.email="null";
          res.status(500).send({ message: err });
          return;
        }
    
        Role.findOne({ name: "user" }, function (err, role)  {
            if (err) {
               req.session.email="null";
              res.status(500).send({ message: err });
              return;
            }
    
            user.roles = [role._id];
            user.save(err => {
              if (err) {
                req.session.email="null";
                res.status(500).send({ message: err });
                return;
              }
    
    //          res.send({ message: "User was registered successfully!" });
              console.log('Google User data after saving in mongo' + JSON.stringify(user));
              req.session.email=user.email;
          //    req.session.token=req.body.id_token;
              console.log('sid in tokensignin after setting:' + req.session.id);
              console.log('session in tokensignin after setting:' + JSON.stringify(req.session));
          
             res.status(200).send({
               userId: user._id,
               username: user.username,
               firstname: user.GivenName,
               lastname: user.FamilyName,
               email: user.email,
             //  roles: authorities,
               accessToken: req.session.token
              
             });
            });
          });
        
      });
    }

    else {  // user found
      console.log('Google User data when found in mongo' + JSON.stringify(user));
      req.session.email=user.email;
  //    req.session.token=req.body.id_token;
      console.log('sid in tokensignin after setting:' + req.session.id);
      console.log('session in tokensignin after setting:' + JSON.stringify(req.session));
   //   return  res.send({ message: "User already existed in the database!" });

      res.status(200).send({
        userId: user._id,
        username: user.username,
        email: user.email,
    //    roles: authorities,
        accessToken: req.session.token
       
      });
    }
    
  });
};

exports.signout = (req, res) =>{

  console.log('session in signout:' + JSON.stringify(req.session));
  console.log('sid in signout:' + req.session.id);
  
  req.session.destroy( function (err)  {

    if (err) {
      res.status(500).send('could not log out!');

    }
    else
    {
      res.clearCookie(process.env.SESS_NAME);
      res.status(200).send ({message: 'OK'});
    }
  });
};

exports.resetpassword= async  (req, res) => {

 

  if (!req.body.email) {
  return res
    .status(500)
    .json({ message: 'Email is required' });
  }
  console.log('reset password:' + req.body.email +'.');

  

  const user = await User.findOne({
    email: req.body.email
  })
   .exec((err, user) => {
    if (err) {
      
      res.status(500).send({ message: err });
      return;
    }
  //  console.log('user:' + JSON.stringify(user) );
  

  if (!user) {
  return res
    .status(409)
    .json({ message: 'Email does not exist' });
  }

  
  //console.log('user:' + JSON.stringify(user) );

 
  var resettoken = new PasswordResetToken({ _userId:  user._id, resettoken: crypto.randomBytes(16).toString('hex') });
  
  resettoken.save(function (err) {
        if (err) { return res.status(500).send({ msg: err.message + 'here'}); }
        PasswordResetToken.find({ _userId: user._id, resettoken: { $ne: resettoken.resettoken } }).remove().exec();
        res.status(200).json({ message: 'Reset Password successfully.' });


        const oauth2Client = new OAuth2(
          process.env.CLIENT_ID, // clientId
          process.env.CLIENT_SECRET, // Client Secret
          process.env.REDIRECT_URL // Redirect URL
      );
      
      oauth2Client.setCredentials({
        refresh_token: process.env.REFRESH_TOKEN
      });
      const accessToken =  oauth2Client.getAccessToken();
      
      const smtpTransport =  nodemailer.createTransport({
        service: "gmail",
        auth: {
             type: "OAuth2",
            
             user: process.env.EMAIL_ACCOUNT,
             clientId: process.env.CLIENT_ID,
             clientSecret: process.env.CLIENT_SECRET,
             refreshToken: process.env.REFRESH_TOKEN,
             accessToken: accessToken
        },
        tls: {
          rejectUnauthorized: false
        }
      });
        var mailOptions = {
            to: user.email,
            from: 'your email',
            subject: ' Password Reset',
            text: 'You are receiving this because you (or someone else) have requested the reset of the password for your account in application.\n\n' +
            'Please click on the following link, or paste this into your browser to complete the process:\n\n' +
            'http://' + process.env.HOST + ':' + process.env.FRONTEND_PORT + '/response-reset-password/' + resettoken.resettoken + '\n\n' +
            'If you did not request this, please ignore this email and your password will remain unchanged.\n'
        }

        smtpTransport.sendMail(mailOptions, (error, response) => {
          error ? console.log(error) : console.log(response);
          smtpTransport.close();
     });
   
  })
});
  };

  exports.validpasswordtoken = async  (req, res) =>{

    console.log ('req.body in validpasswordtoken: ' + JSON.stringify(req.body));
    if (!req.body.resettoken) {
    return res
    .status(500)
    .json({ message: 'Token is required' });
    }
    const user = await  PasswordResetToken.findOne({
    resettoken: req.body.resettoken
    });
    if (!user) {
    return res
    .status(409)
    .json({ message: 'Invalid URL' });
    }
   
    PasswordResetToken.findOne({ _userId: user._userId }).then(() => {
    res.status(200).json({ message: 'Token verified successfully.' });
    }).catch((err) => {
    return res.status(500).send({ msg: err.message });
    });
};

    exports.newpassword= async (req, res) => {

    //  console.log ('req.body in newpassword: ' + JSON.stringify(req.body));
      const userToken = await PasswordResetToken.findOne({ resettoken: req.body.resettoken }, function (err, userToken, next) {
          if (!userToken) {
            return res
              .status(409)
              .json({ message: 'Token has expired' });
          }
    
          console.log ('userToken: ' + JSON.stringify(userToken));
           User.findOne({
            _id: userToken._userId
          }, function (err, userEmail, next) {
            if (!userEmail) {
              return res
                .status(409)
                .json({ message: 'User does not exist' });
            }
          
            return bcrypt.hash(req.body.newPassword, 8, (err, hash) => {
              if (err) {
                return res
                  .status(400)
                  .json({ message: 'Error hashing password' });
              }
              userEmail.password = hash;
              userEmail.save(function (err) {
                if (err) {
                  return res
                    .status(400)
                    .json({ message: 'Password can not reset.' });
                } else {
                  userToken.remove(function(err){
                    if (err){
                      {
                        return res
                          .status(400)
                          .json({ message: 'Error removing token' });
                      }
                    }
                  });
                  return res
                    .status(201)
                    .json({ message: 'Password reset successfully' });
                }
    
              });
            });
          });
    
        })
    };
