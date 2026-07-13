const { user } = require("../models");
const db = require("../models");
const Hskill = db.hardskill;

exports.getHardSkills = async (req, res) => {
    try {
        const hs = await Hskill.find();
        res.send(hs);
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.updateHardSkills = async (req, res) => {
    try {
        await Hskill.findByIdAndUpdate(req.params.id, req.body);
        res.status(200).send({
            message: "Hardskill Updated Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.createHardSkills = async (req, res) => {
    try {
        const newHS = new Hskill(req.body);
        await newHS.save();
        res.status(200).send({
            message: "Hardskill Created Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.deleteHardSkills = async (req, res) => {
    try {
        await Hskill.findByIdAndDelete(req.params.id);
        res.status(200).send({
            message: "Hardskill Deleted Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};