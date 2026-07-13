var session = require('express-session');
var Keycloak = require('keycloak-connect');

let _keycloak;

var keycloakConfig = {
    clientId: 'nodejs',
    bearerOnly: true,
    serverUrl: 'http://127.0.0.1:8080/auth',
    realm: 'myrealm',
    credentials: {
        secret: '8e90a722-ad0c-4da0-bbcf-0abe7f71f740'
    }
};

function initKeycloak() {
    if (_keycloak) {
        console.warn("Trying to init Keycloak again!");
        return _keycloak;
    } 
    else {
        console.log("Initializing Keycloak...");
        var memoryStore = new session.MemoryStore();
       
        _keycloak = new Keycloak({ store: memoryStore }, keycloakConfig);
        return _keycloak;
    }
}

function getKeycloak() {
    if (!_keycloak){
        console.error('Keycloak has not been initialized. Please called init first.');
    } 
    return _keycloak;
}

function validateToken() {
    try {
        const user =  keycloak.verifyOnline(accessToken);
        console.log('After token validation, the user is:' + user);
     } 
     catch(e){ 
         console.log('Token is not valid.');
     }
}

module.exports = {
    initKeycloak,
    getKeycloak,
    validateToken
};