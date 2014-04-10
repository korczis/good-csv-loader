App = Ember.Application.create({
  LOG_TRANSITIONS: true,
});

// HELPERS

App.Router.map(function() {
  this.route("index", {path: "/"});
});

App.IndexRoute = Ember.Route.extend({
  model: function() {
    return ['file', 'file', 'file'];
  },
});

App.IndexController = Ember.Controller.extend({
  creatingConnection: true,
  status: null,
  init: function(){
    console.log("here");
  },
  actions: {
    requestUUID: function(){
      controller = this;
      controller.set('status', "Requesting UUID...");
    },
  }

});