var express = require('express')
var app = express()

app.get('/api6/foo', function( req, res ) {
  var d = new Date().toISOString()
  res.send('this is express at '+d)
})

app.listen(3000, function() {
  console.log('Express app running at port 3000')
})
