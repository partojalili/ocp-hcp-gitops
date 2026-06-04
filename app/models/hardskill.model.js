const mongoose = require("mongoose");

const Hardskill = mongoose.model(
  "Hardskill",
  new mongoose.Schema({
    name: String
  },{
      versionKey: false
  })
);

module.exports = Hardskill;