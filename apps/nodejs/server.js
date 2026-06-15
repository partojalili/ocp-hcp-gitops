
const express = require("express");



const bodyParser = require("body-parser");
const cors = require("cors");
const path = require('path');
const session =require("express-session");
//const config = require("./app/config/auth.config");
//const cookieParser = require('cookie-parser');
//const controller = require("./app/controllers/user.controller");
const MongoStore = require('connect-mongo')(session);
const mongoose = require('mongoose');

//const Keycloak = require('keycloak-connect');
//const session = require('express-session');

var jwt = require("jsonwebtoken");
var bcrypt = require("bcryptjs");
const db = require("./app/models");

const keycloak = require('./app/config/keycloak-config.js').initKeycloak();





 if (process.env.NODE_ENV !== 'production') {
   require('dotenv').config({path: path.resolve('env'),})
 };

const {
 HOST = process.env.HOST,
 HOSTDB = process.env.HOSTDB,
 DBPORT = process.env.DBPORT,
 PORT = process.env.PORT,
 DB = process.env.DB,
 NODE_ENV = process.env.NODE_ENV,
 SESS_NAME = process.env.SESS_NAME,
 SESS_LIFETIME  = process.env.SESS_LIFETIME,
 FRONTEND_PORT = process.env.FRONTEND_PORT
} = process.env



//console.log(`This is the port ` + ${path});

const app = express();


var corsOptions = {
 // origin: "http://localhost:8081",
  origin:  'http://' + process.env.HOST + ':' + process.env.FRONTEND_PORT,
 // origin: '*' ,
 //origin: '*',
  credentials: true,
  
};

app.use(cors(corsOptions));


// parse requests of content-type - application/json
// app.use(bodyParser.urlencoded({
//   extended: false
// }))
app.use(express.urlencoded({ extended: true }))
//app.use(bodyParser.json());
app.use(express.json());

//app.use(bodyParser());
//var cookieParser = require('cookie-parser');
// app.use(express.cookieParser('secret'));
// app.use(express.cookieSession());


// parse requests of content-type - application/x-www-form-urlencoded
//app.use(bodyParser.urlencoded({ extended: false }));
//app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.use(session({
  name: SESS_NAME,
  secret: 'thisisasecret',
  saveUninitialized: false,
  store: new MongoStore({ mongooseConnection: mongoose.connection }),
  resave: false ,
  cookie: {
    sameSite: true,
    secure: false,
    maxAge: Number.SESS_LIFETIME
  }
 }));

 app.use(function(req, res, next) {  
  res.header('Access-Control-Allow-Origin', req.headers.origin);
 // res.header('Access-Control-Allow-Origin', "*");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  res.header("Access-Control-Allow-Headers","*");
  res.header('Access-Control-Allow-Credentials', true);
  res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE');
  res.header("Access-Control-Expose-Headers", "*");
 
  
  next();
});  


//app.use(cookieParser);
//const db = require("./app/models");
//const { resolveTypeReferenceDirective } = require("typescript");
const Role = db.role;
const User = db.user;


db.mongoose
  .connect(`mongodb://${HOSTDB}:${DBPORT}/${DB}`, {
   
 
    useNewUrlParser: true,
    useUnifiedTopology: true
  })
  .then(() => {
    console.log("Successfully connect to MongoDB..." + `${HOSTDB}:${DBPORT}/${DB}`);
    console.log('process.env.NODE_ENV:' + process.env.NODE_ENV)
    initial();
  })
  .catch(err => {
    console.error("Connection error", err);
    process.exit();
  });


function initial() {
  Role.estimatedDocumentCount((err, count) => {
    if (!err && count === 0) {
      new Role({
        name: "user"
      }).save(err => {
        if (err) {
          console.log("error", err);
        }

        console.log("added 'user' to roles collection");
      });

      new Role({
        name: "moderator"
      }).save(err => {
        if (err) {
          console.log("error", err);
        }

        console.log("added 'moderator' to roles collection");
      });

      new Role({
        name: "admin"
      }).save(err => {
        if (err) {
          console.log("error", err);
        }

        console.log("added 'admin' to roles collection");
      });
    }
  });
}
app.use(keycloak.middleware());


// simple route
app.get("/",  (req, res) => {
    
  //    console.log('sid in /'+ req.sessionID);
    
  //  //  console.log('header' + res.header)
  //    if (!req.session.email){
  //     req.session.email='test@test.com';
  //     res.json({ message: "You must be logged in. I have logged you in." });
         
  //    }
  //    else{
  //     res.json({ message: "You are authorized." });
  //   }
  //   console.info('req.headers =', req.headers, ';');
      res.json({ message: "Welcome to Demo application." });
 
});



require('./app/routes/auth.routes')(app);
require('./app/routes/user.routes')(app);
require('./app/routes/certification.routes')(app);
require('./app/routes/hardskill.routes')(app);
require('./app/routes/personality.routes')(app);
require('./app/routes/softskill.routes')(app);
require('./app/routes/kafka.routes')(app);



// set port, listen for requests
//const PORT = process.env.PORT ;
app.listen(PORT, () => {

  console.log(`Server is running on port ` + PORT + `.`);
});