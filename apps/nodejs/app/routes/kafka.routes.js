const controller = require("../controllers/kafka.controller");

module.exports = function(app) {
    app.use(function(req, res, next) {
      res.header(
        "Access-Control-Allow-Headers",
        "x-access-token, Origin, Content-Type, Accept"
      );
      next();
    });
  

app.post('/newCustomer',function(req,res){
    payloads = [{ topic: constants.TOPIC_CUSTOMERS, messages:req.body.message , partition: 0 }];
    producer.send(payloads, function (err, data) {
     res.json(data);
    });
   });

   app.post('/kill', (req, res) => {
    console.log(count++);
  var args = {
    openid: 'b05NZ2Y1WjbE9fRV9MZTBWWQ==',
    seckillTime: '2018-12-12 00:00:01',
  }
  let payload=[{
    topic:'PROUDCT_NUMBER',
    messages:[JSON.stringify(args)],
    key:"seckill",
    partition:0
  }];
  producer.send(payload,function(err,data){
                console.log(data);
              });
  });


 
  app.post('/sendMsg', controller.producer );

  app.post('/receiveMsg', controller.consumer );
  
 



  app.post('/newTransaction',function(req,res){
    var msg = JSON.stringify(req.body.message);
    payloads = [{ topic: constants.TOPIC_TRANSACTIONS, messages:msg , partition: 0 }];
    console.log(payloads);
    producer.send(payloads, function (err, data) {
     res.json(data);
    });
   });

};