import { Component, OnInit } from '@angular/core';
// import { interval, Subscription } from 'rxjs';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormsModule } from '@angular/forms';


@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent implements OnInit{
  constructor(private http: HttpClient){

  }
  title = 'my-app';

  configShow = false;

  liveReading = null;
  recentTempReading = null;
  violationLogs = null;
  

  setConfigShow(x: boolean) {
    this.configShow = x;
    console.log("clicked clicked")
  }

  sensorName:string='';
  sensorLoc:string='';
  smsNum:string = '';
  threshold:number = 0;

  intervalReadings = setInterval(()=>{
    const headers= new HttpHeaders()
      .set('Access-Control-Allow-Origin', 'http://localhost:4200/');
    this.http.get<any>('http://localhost:3000/sky/event/ckldpvh6l002p30j403o18ekp/temp/wovyn/recentreadings',{'headers': headers}).subscribe(data => {
      this.recentTempReading = data.directives[0].options;
      let c = this.recentTempReading[this.recentTempReading.length - 1]

      this.liveReading = c.temperature.toString() + " at " + c.timestamp
      // console.log(this.recentTempReading)
    })
  }, 10000);

  intervalVio = setInterval(()=>{
    const headers= new HttpHeaders()
      .set('Access-Control-Allow-Origin', 'http://localhost:4200/');
    this.http.get<any>('http://localhost:3000/sky/event/ckldpvh6l002p30j403o18ekp/temp/wovyn/violations',{'headers': headers}).subscribe(data => {
      this.violationLogs = data.directives[0].options;
      // console.log(this.violationLogs)
    })
  }, 10000);

  saveConfig(){
    const headers= new HttpHeaders()
      .set('Access-Control-Allow-Origin', 'http://localhost:4200/');
    let x = {name: this.sensorName, location: this.sensorLoc, number:this.smsNum, threshold: this.threshold};
    
    this.http.post('http://localhost:3000/sky/event/ckldpvh6l002p30j403o18ekp/temp/sensor/profile_updated', x, {'headers': headers}).subscribe(data => {
    })
    this.http.get<any>('http://localhost:3000/sky/event/ckldpvh6l002p30j403o18ekp/temp/sensor/get_profile',{'headers': headers}).subscribe(data => {
      
      this.threshold = data.directives[0].options.threshold;
      this.smsNum = data.directives[0].options.number;
      this.sensorLoc = data.directives[0].options.location;
      this.sensorName = data.directives[0].options.name
    })
    this.configShow = false;
  }
  ngOnInit() {
    const headers= new HttpHeaders()
      .set('Access-Control-Allow-Origin', 'http://localhost:4200/');
    this.http.get<any>('http://localhost:3000/sky/event/ckldpvh6l002p30j403o18ekp/temp/sensor/get_profile',{'headers': headers}).subscribe(data => {
      
      this.threshold = data.directives[0].options.threshold;
      this.smsNum = data.directives[0].options.number;
      this.sensorLoc = data.directives[0].options.location;
      this.sensorName = data.directives[0].options.name
    })
    this.http.get<any>('http://localhost:3000/sky/event/ckldpvh6l002p30j403o18ekp/temp/wovyn/recentreadings',{'headers': headers}).subscribe(data => {
      this.recentTempReading = data.directives[0].options;
      let c = this.recentTempReading[this.recentTempReading.length - 1]

      this.liveReading = c.temperature.toString() + " at " + c.timestamp
      // console.log(this.recentTempReading)
    })
    this.http.get<any>('http://localhost:3000/sky/event/ckldpvh6l002p30j403o18ekp/temp/wovyn/violations',{'headers': headers}).subscribe(data => {
      this.violationLogs = data.directives[0].options;
      // console.log(this.violationLogs)
    })
  }


  ngOnDestroy() {
    clearInterval(this.intervalReadings);
    clearInterval(this.intervalVio);
  }

}

