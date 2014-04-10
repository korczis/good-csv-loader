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
  // TODO: Add an observers that automatically checks when email is updated to see if it mataches with the seesion id.
  email: null,
  init: function(){

    $("#files").hide();
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
          $("#swoosh").show(900);
          $("#files").show();
          $('.email-notification').modal('show');
        }
      }
      // NOTE: Make request to server for UUID.
      $.ajax(getUUID);
    },
    createProject: function() {
      controller = this;
      uuid = controller.get('uuid');
      newProject = {
        url: '/publications/'+uuid,
        method: 'POST',
        error: function(xml, err, status){
          controller.set('status', err);
        },
        success: function(data){
          console.log(data);
          controller.set('status', null);
        }
      }
      $.ajax(launchProject);
    },
    setEmail: function(){
      controller = this;
      email = $('#email').val();
      if(email.split('@').length < 2){
          $('.email-notification').modal('show');
          alert('We do need an email to pair with your project.');
      } else {
        $('.email-notification').modal('hide');
        controller.set('email', email);
      }
    },
    cancel: function() {
      console.log('POST DATA');
      uuid = this.get('uuid');
      this.set('uuid', "CLOSED "+uuid);
      $("#swoosh").hide(900);
      $("#files").hide();
      $("#startSession").show();
      $("#startSession").html('New Session');
    }
  }

});