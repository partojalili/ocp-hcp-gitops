const { user } = require("../models");
const db = require("../models");
const Sskill = db.softskill;

exports.getSoftSkills = async (req, res) => {
    try {
        const ss = await Sskill.find();
        res.send(ss);
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.updateSoftSkills = async (req, res) => {
    try {
        await Sskill.findByIdAndUpdate(req.params.id, req.body);
        res.status(200).send({
            message: "Softskill Updated Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.createSoftSkills = async (req, res) => {
    try {
        const newSS = new Sskill(req.body);
        await newSS.save();
        res.status(200).send({
            message: "Softskill Created Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.deleteSoftSkills = async (req, res) => {
    try {
        await Sskill.findByIdAndDelete(req.params.id);
        res.status(200).send({
            message: "Softskill Deleted Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};