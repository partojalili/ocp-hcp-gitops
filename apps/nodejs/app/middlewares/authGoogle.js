


verifyGoogleToken = (req, res, next) =>{

    const CLIENT_ID = process.env.CLIENT_ID;
    const {OAuth2Client} = require('google-auth-library');
    const client = new OAuth2Client(CLIENT_ID);
   
    let token = req.body.id_token;
    console.log('token in verifyGoogleToken:' + token)
    async function verify() {
     // function verify() {
        try{
        const ticket = await client.verifyIdToken({
     //   const ticket =  client.verifyIdToken({
        idToken: token,
        audience: CLIENT_ID 
    }) 
    
    const payload = ticket.getPayload();
    const userid = payload['sub'];
    const email = payload['email'];
    console.log('userid collected in verifyGoogleToken:' + userid);
    console.log('email collected in verifyGoogleToken:' + email);
  //  req.session.email='parto@utp.foundation';
 //   req.session.token=token;
    console.log('Google token in :verifyGoogleToken' + token);
    console.log('session in verifyGoogleToken:' + JSON.stringify(req.session));
    console.log('sid in verifyGoogleToken:' + req.session.id);
    next();
}
catch (e)
{
   return res.status(401).send({ message: "Unauthorized google user!" });
}

    }

    verify().catch(console.error());
  //  next();
    //.catch(console.error());
   
    
    
};



const authGoogle = {
    verifyGoogleToken
  };
  module.exports = authGoogle;
 