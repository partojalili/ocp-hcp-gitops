const { user } = require("../models");
const db = require("../models");
const Personality = db.personality;

exports.getPers = async (req, res) => {
    try {
        const pers = await Personality.find();
        console.log('pers:' + pers);
        res.send(JSON.stringify(pers));
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.updatePers = async (req, res) => {
    try {
        await Personality.findByIdAndUpdate(req.params.id, req.body);
        res.status(200).send({
            message: "Personality Updated Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.createPers = async (req, res) => {
    try {
        const newPers = new Personality(req.body);
        await newPers.save();
        res.status(200).send({
            message: "Personality Created Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.deletePers = async (req, res) => {
    try {
        await Personality.findByIdAndDelete(req.params.id);
        res.status(200).send({
            message: "Personality Deleted Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};