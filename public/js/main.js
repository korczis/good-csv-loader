App = Ember.Application.create({
  LOG_TRANSITIONS: true,
});

// FAYE
// NOTE: EXAMPLE -> fclient.publish('/foo', {"message" : message || "hello"});
var fclient = new Faye.Client('http://54.205.230.19:9292/faye');

App.Router.map(function() {
  this.route("index", {path: "/"});
});

App.store = DS.Store.extend({
  revision: 12,
});

App.FileView = Ember.View.extend({
  key: function(){
    return "ITS NOT WHAT THE KEY WAS";
  }
});

App.FileDetailsComponent = Ember.Component.extend({
  file: null,
  name: null,
  columns: null,
});

App.ApplicationAdapter = DS.LSAdapter;

DS.JSONSerializer.reopen({

    serializeBelongsTo: function(record, json, relationship) {
        var key = relationship.key,
        belongsTo = Ember.get(record, key);
        key = this.keyForRelationship ? this.keyForRelationship(key, "belongsTo") : key;

        if (relationship.options.embedded === 'always') {
            json[key] = belongsTo.serialize();
        }
        else {
            return this._super(record, json, relationship);
        }
    },

    //NOTE: Preps the serializer for a HAS MANY >> Watch for stack loops.
    serializeHasMany: function(record, json, relationship) {
        var key = relationship.key,
            hasMany = Ember.get(record, key),
            relationshipType = DS.RelationshipChange.determineRelationshipType(record.constructor, relationship);

        if (relationship.options.embedded === 'always') {
            if (hasMany && relationshipType === 'manyToNone' || relationshipType === 'manyToMany' ||
                relationshipType === 'manyToOne') {

                json[key] = [];
                hasMany.forEach(function(item, index){
                    json[key].push(item.serialize());
                });
            }

        }
        else {
            return this._super(record, json, relationship);
        }
    }
});

App.IndexRoute = Ember.Route.extend({
  model: function() {
    return this.get('store').find('file');
  },
});

App.File = DS.Model.extend({
    filename: DS.attr('string'),
    uuid: DS.attr('string'),
    creationDate : DS.attr('date'),
    columns: DS.hasMany('column', { embedded: "always"}),
});

App.Column = DS.Model.extend({
    filename: DS.belongsTo('file'),
    name: DS.attr('string'),
});

App.IndexController = Ember.ArrayController.extend({

  needs: ['index'],
  status: null,
  uuid: null,
  uuidObject: null,
  files: null,
  message: null,
  references: null,
  // TODO: Add an observers that automatically checks when email is updated to see if it mataches with the seesion id.
  email: null,

  messageTransformer: function(){
    this._super();
    controller = this;
    uuid = controller.get('uuid');
    message = JSON.parse(this.get('message'));
    store = this.get('store');

        // NOTE: Determine CONTEXT of message.
        if(message.file_added){

            data = store.getById(App.File, message.file_added.filename);
              if(data){
                controller.set(status, "The server is sending files with duplicate names. If you feel this is in error, reset your storage by clicking cancel then clear storage.")
              //} else {
              //  alert("File was already in the store: "+ message.file_added.filename);
              //}
              } else {

                var newFile = store.createRecord('file', {
                  id: message.file_added.filename,
                  filename: message.file_added.filename,
                  uuid: uuid,
                  creationDate: new Date(),
                });

                newFile.save();

              }

        }

        // NOTE: Determine CONTEXT of message.
        else if (message.file_inspected){

            var file = store.getById(App.File, message.file_inspected.filename);

            function commitColumns(column){
              newColumn = store.createRecord('column', {
                filename: message.file_inspected.filename,
                name: column.name,
              });
              try {
                file.get('columns').addObject(newColumn);
                newColumn.save();

              } catch (err){
                controller.set(status, "Your local application must be refreshed: "+err);
              }
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
          var subscription = fclient.subscribe('/' + data.id, function(message) {
                controller.set('message', message);
          });
          controller.set('S3', data.upload_files_uri);
          console.log(data);
          $("#startSession").hide(30);
          $("#swoosh").show(900);
          $("#files").show();
          //TODO: Reactivate this after done testing.
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
      localStorage.clear();
      $("#startSession").show();
      $("#startSession").html('New Session');
    },
    tmpDELETE: function() {
      fileTransformer = this.get('fileTransformer')
      console.log(fileTransformer);
    }
  },
  renderTemplate: function() {
    this.render('file');
  }

});