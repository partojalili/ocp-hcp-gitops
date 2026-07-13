
const kafka = require('kafka-node');
const bp = require('body-parser');
const config = require('../config/kafka.config');


exports.producer = async (req, res) => {

try {

    var sentMessage = JSON.stringify( req.body);
    console.log('setMessage:' + sentMessage);
    // payloads = [
    //   { topic: req.body.topic, messages:sentMessage , partition: 0 }
    // ];
    // producer.send(payloads, function (err, data) {
    //     res.json(data);
    //     console.log(data);
    // });
    
   
   
    let kafkaHost = 'localhost:9092';
  //  const Consumer = kafka.Consumer;
    const client = new kafka.KafkaClient({kafkaHost: kafkaHost});


  const Producer = kafka.Producer;
 // const client = new kafka.Client(config.kafka_server);
  const producer = new Producer(client);
  const kafka_topic = 'example';
  console.log('kafka_topic:' + kafka_topic);
  let payloads = [
    {
      topic: kafka_topic,
     // messages: config.kafka_topic
     messages: sentMessage
    }
  ];

  producer.on('ready', async function() {
    let push_status = producer.send(payloads, (err, data) => {
      if (err) {
        console.log('[kafka-producer -> '+kafka_topic+']: broker update failed');
      } else {
        console.log('[kafka-producer -> '+kafka_topic+']: broker update success');
        console.log('[kafka-message -> '+JSON.stringify(payloads)+']: broker update success');
        
      }
    });
  });

  producer.on('error', function(err) {
    console.log(err);
    console.log('[kafka-producer -> '+kafka_topic+']: connection errored');
    throw err;
  });
}
catch(e) {
  console.log(e);
}
}


exports.consumer = async (req, res) => {
try {

    let kafkaHost = 'localhost:9092';
    //  const Consumer = kafka.Consumer;
      const client = new kafka.KafkaClient({kafkaHost: kafkaHost});

   // const Consumer = kafka.HighLevelConsumer;
    //const client = new kafka.Client(config.kafka_server);
    const Consumer = kafka.Consumer;

    let consumer = new Consumer(
      client,
      [{ topic: config.kafka_topic, partition: 0 }],
      {
        autoCommit: true,
        fetchMaxWaitMs: 1000,
        fetchMaxBytes: 1024 * 1024,
        encoding: 'utf8',
        fromOffset: false
      }
    );
    consumer.on('message', async function(message) {
      console.log('here');
      console.log(
        'kafka-> ',
        message.value
      );
    })
    consumer.on('error', function(err) {
      console.log('error', err);
    });
  }
  catch(e) {
    console.log(e);
  }
}