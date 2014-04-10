App = Ember.Application.create({
  LOG_TRANSITIONS: true,
});

// FAYE
var fclient = new Faye.Client('/faye');


            var send_hello = function(message) {
                fclient.publish('/foo', {"message" : message || "hello"});
            };

App.Router.map(function() {
  this.route("index", {path: "/"});
});

App.IndexRoute = Ember.Route.extend({
  model: function() {
    return ['file', 'file', 'file'];
  },
});

App.IndexController = Ember.Controller.extend({
  status: null,
  uuid: null,
  files: null,
  init: function(){
    console.log('here');
    var subscription = fclient.subscribe('/foo', function(message) {
      alert(JSON.stringify(message));
    });
  },
  actions: {
    requestUUID: function(){
      controller = this;
      controller.set('status', "Requesting UUID...");

      getUUID = {
        url: '/projects',
        error: function(xml, err, status){
          controller.set('status', err);
        },

        method: 'POST',
        success: function(data){
          controller.set('status', null);
          controller.set('uuid', data.id);
          controller.controllerFor('application').set('uuid', data.id);
          controller.set('S3', data.upload_files_uri);
          console.log(data);
          $("#startSession").hide(30);
        }
      }
      $.ajax(getUUID);
    },
  }

});