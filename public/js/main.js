App = Ember.Application.create({
  LOG_TRANSITIONS: true,
});

// FAYE
var fclient = new Faye.Client('http://54.205.230.19:9292/faye');

            var send_hello = function(message) {
                fclient.publish('/foo', {"message" : message || "hello"});
            };

App.Router.map(function() {
  this.route("index", {path: "/"});
});

App.store = DS.Store;

App.ApplicationAdapter = DS.LSAdapter;

App.IndexRoute = Ember.Route.extend({
  model: function() {
    return this.get('store').find('file');
  },
});

App.File = DS.Model.extend({
    filename: DS.attr('string'),
    uuid: DS.attr('string'),
    creationDate : DS.attr('date'),
    columns: DS.hasMany('column', {async: true}),
});

App.Column = DS.Model.extend({
    name: DS.attr('string'),
});

App.IndexController = Ember.Controller.extend({

  status: null,
  uuid: null,
  uuidObject: null,
  files: null,
  message: null,
  // TODO: Add an observers that automatically checks when email is updated to see if it mataches with the seesion id.
  email: null,

  messageController: function(){
    this._super();
    controller = this;
    message = this.get('message');
    files = controller.get('files');

        // NOTE: Determine CONTEXT of message.
        if(message.file_added){

            this.store.find(App.File, { filename: message.file_added.filename}).then(function(data){

              if(!data.content.length){
                var newFile = controller.store.createRecord('file', {
                  filename: message.file_added.filename,
                  uuid: controller.get('uuid'),
                  creationDate: new Date()
                });
                newFile.save();
              } else {
                alert("File was already in the store: "+ message.file_added.filename);
              }
            });

        }

        // NOTE: Determine CONTEXT of message.
        else if (message.file_inspected){

          function commitColumns(column){
            newColumn = controller.store.createRecord('column', {
              name: column.name,
            });
            record = controller.store.find(App.File, { filename: message.file_inspected.filename}).then(function(file){
              console.log(file);
              file.get('columns').then(function(){
                pushObject(newColumn);
                file.save(); console.log(newColumn);
              });
            });
          }
          for(i=0;i<message.file_inspected.columns.length;i++){
            commitColumns(message.file_inspected.columns[i])
          }

        }

  }.observes('message'),

  init: function(){
    
    
    controller = this;
    $("#files").hide();
    //NOTE: Listen for any messages to update the 'message' property with.
    var subscription = fclient.subscribe('/foo', function(message) {

        controller.set('message', message);

    });
  },
  actions: {
    requestUUID: function(){
      controller = this;
      controller.set('status', "Requesting UUID...");

      getUUID = {
        url: '/projects',
        error: function(xml, err, status){
          controller.controllerFor('application').set('status', "Sorry about this..."+status);
        },

        method: 'POST',
        success: function(data){
          controller.set('status', null);
          controller.set('uuidObject', null);
          controller.set('uuid', data.id);
          console.log(data.id);
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