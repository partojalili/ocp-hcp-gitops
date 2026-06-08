const { user } = require("../models");
const db = require("../models");
const Cert = db.certification;

exports.getCerts = async (req, res) => {
    try {
        const certs = await Cert.find();
        res.send(certs);
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.updateCert = async (req, res) => {
    try {
        await Cert.findByIdAndUpdate(req.params.id, req.body);
        res.status(200).send({
            message: "Certification Updated Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.createCert = async (req, res) => {
    try {
        const newCert = new Cert(req.body);
        await newCert.save();
        res.status(200).send({
            message: "Certification Createdd Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};

exports.deleteCert = async (req, res) => {
    try {
        await Cert.findByIdAndDelete(req.params.id);
        res.status(200).send({
            message: "Certification Deleted Successfully."
        });
    } catch (error) {
        res.status(500).send({ message: error });
    }
};