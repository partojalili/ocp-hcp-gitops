const mongoose = require('mongoose');
mongoose.Promise = global.Promise;

const db = {};

db.mongoose = mongoose;

db.user = require("./user.model");
db.role = require("./role.model");
db.resettoken = require("./resettoken.model")
db.certification = require("./certifications.model");
db.hardskill = require("./hardskill.model");
db.personality = require("./personality.model");
db.softskill = require("./softskill.model");
db.session = require("./session.model")

db.ROLES = ["user", "admin", "moderator"];

module.exports = db;