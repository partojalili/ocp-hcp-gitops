const mongoose = require('mongoose');

const PasswordResetToken = mongoose.model(
  "PasswordResetToken",
  new mongoose.Schema({
   
    _userId: { type: mongoose.Schema.Types.ObjectId, required: true , ref: "User" },
    resettoken: { type: String, required: true },
    createdAt: { type: Date, required: true, default: Date.now, expires: 43200 },
  })
);

module.exports = PasswordResetToken;