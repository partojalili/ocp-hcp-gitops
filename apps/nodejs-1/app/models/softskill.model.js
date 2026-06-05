const mongoose = require("mongoose");

const Softskill = mongoose.model(
  "Softskill",
  new mongoose.Schema({
    name: String
  },{
      versionKey: false
  })
);


module.exports = Softskill;