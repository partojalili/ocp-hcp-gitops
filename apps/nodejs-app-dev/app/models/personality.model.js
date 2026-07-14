const mongoose = require("mongoose");

const Personality = mongoose.model(
  "personalities",
  new mongoose.Schema({
    name: String
  },{
      versionKey: false
  })
);


module.exports = Personality;