const mongoose = require("mongoose");

const Certifications = mongoose.model(
  "Certifications",
  new mongoose.Schema({
    name: String
  },{
      versionKey: false
  })
);


module.exports = Certifications;