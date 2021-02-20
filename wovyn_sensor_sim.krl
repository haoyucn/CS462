ruleset wovyn_sensor_sim {
    meta {
      name "wovyn_sensor_sim"
      configure using 
        heart_beat_second = 0  
      provides send_heartbeat
    }
    global {
      send_heartbeat = defaction(temp) {
        every {
          http:post(<<http://192.168.1.2:3000/sky/event/ckldpvh6l002p30j403o18ekp/temp/wovyn/heartbeat>>
            ,
            json={
              "emitterGUID":"5CCF7F2BD537",
              "eventDomain":"wovyn.emitter",
              "eventName":"sensorHeartbeat",
              "genericThing":{
                "typeId":"2.1.2",
                "typeName":"generic.simple.temperature",
                "healthPercent":56.89,
                "heartbeatSeconds":10,
                "data":{
                  "temperature":[
                    {
                      "name":"ambient temperature",
                      "transducerGUID":"28E3A5680900008D",
                      "units":"degrees",
                      "temperatureF":temp,
                      "temperatureC":24.06
                    }
                  ]
                }
              },
              "property":{
                "name":"Wovyn_2BD537",
                "description":"Temp1000",
                "location":{
                  "description":"Timbuktu",
                  "imageURL":"http://www.wovyn.com/assets/img/wovyn-logo-small.png",
                  "latitude":"16.77078",
                  "longitude":"-3.00819"
                }
              },
              "specificThing":{
                "make":"Wovyn ESProto",
                "model":"Temp1000",
                "typeId":"1.1.2.2.1000",
                "typeName":"enterprise.wovyn.esproto.wtemp.1000",
                "thingGUID":"5CCF7F2BD537.1",
                "firmwareVersion":"Wovyn-WTEMP1000-1.14",
                "transducer":[
                  {
                    "name":"Maxim DS18B20 Digital Thermometer",
                    "transducerGUID":"28E3A5680900008D",
                    "transducerType":"Maxim Integrated.DS18B20",
                    "units":"degrees",
                    "temperatureC":24.06
                  }
                ],
                "battery":{
                  "maximumVoltage":3.6,
                  "minimumVoltage":2.7,
                  "currentVoltage":3.21
                }
              },
              "version":2
            }
            
            ) setting(response)
            send_directive("message_sent", {"content": response{"content"}.decode()}) 
        }
      }

      send_heartbeat_no_g = defaction() {
        every {
          http:post(<<http://192.168.1.2:3000/sky/event/ckku3kpa900mhkmj421l66168/temp/wovyn/heartbeat>>
            ,
            json={
              "emitterGUID":"5CCF7F2BD537",
              "eventDomain":"wovyn.emitter",
              "eventName":"sensorHeartbeat",
              "property":{
                "name":"Wovyn_2BD537",
                "description":"Temp1000",
                "location":{
                  "description":"Timbuktu",
                  "imageURL":"http://www.wovyn.com/assets/img/wovyn-logo-small.png",
                  "latitude":"16.77078",
                  "longitude":"-3.00819"
                }
              },
              "specificThing":{
                "make":"Wovyn ESProto",
                "model":"Temp1000",
                "typeId":"1.1.2.2.1000",
                "typeName":"enterprise.wovyn.esproto.wtemp.1000",
                "thingGUID":"5CCF7F2BD537.1",
                "firmwareVersion":"Wovyn-WTEMP1000-1.14",
                "transducer":[
                  {
                    "name":"Maxim DS18B20 Digital Thermometer",
                    "transducerGUID":"28E3A5680900008D",
                    "transducerType":"Maxim Integrated.DS18B20",
                    "units":"degrees",
                    "temperatureC":24.06
                  }
                ],
                "battery":{
                  "maximumVoltage":3.6,
                  "minimumVoltage":2.7,
                  "currentVoltage":3.21
                }
              },
              "version":2
            }
            
            ) setting(response)
            send_directive("message_sent", {"content": response{"content"}.decode()}) 
        }
      }
      

    }
    rule send_heartbeat_once {
      select when wovynsim singleheartbeat
      pre{
        temp = event:attrs{"temp"} || math:round(random:number(lower = 70, upper = 76),2)
      }
      send_heartbeat(temp)
    }

    rule send_heartbeat_once_no_generic {
      select when wovynsim singleheartbeat_nogeneric
      send_heartbeat_no_g()
    }

    rule schedule_heartbeat {
      select when wovynism schedule_heartbeat
      send_directive("heartbeat scheduled", {"interval": "set heartbeat to every 20 second"}) 
      always{
        schedule wovynsim event "singleheartbeat" repeat "*/20 * * * * *"
      }
    }

    rule schedule_list {
      select when wovynsim list

      send_directive("all schedules", schedule:list())
    }

    rule schedule_rm {
      select when wovynsim remove
      pre {
        id = event:attrs{"id"}
      }
      schedule:remove(id)
    }
  }
  
  
// w base channels allow *:
// ckku3kpa900mhkmj421l66168