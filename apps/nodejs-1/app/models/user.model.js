const mongoose = require("mongoose");

const User = mongoose.model(
  "User",
  new mongoose.Schema({
    firstname: String,
    lastname: String,
    username: String,
    email: String,
    address: 
     {
      street: String,
      city: String,
      state: String,
      zipcode: String
     }
    ,
    password: String,
    roles: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Role"
      }
    ],
    IsGoogleUser: String,
  })
);

module.exports = User;