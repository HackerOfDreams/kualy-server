async = require 'async'

UsersController =

  update: (req, res) ->
    unless req.form.isValid
      req.json {errors: req.form.errors}, 422
    else
      userId = req.param('id')
      Users.find(userId).done (error, user) ->
        if error then return res.json({error}, 500)
        unless user then return res.json({error:'No user with that id'}, 404)

        # Update user with existing fields
        user.name = req.form.name if req.form.name
        user.username = req.form.username if req.form.username
        user.bio = req.form.bio if req.form.bio
        user.email = req.form.email if req.form.email

        Users.update user.id, user, (error, updatedUser) ->
          if error then return res.json({error}, 500)
          res.json updatedUser, 200

  followCause: (req, res) ->
    unless req.form.isValid
      req.json {errors: req.form.errors}, 422
    else
      userId = req.param('id')
      Users.find(userId).done (error, user) ->
        if error then return res.json({error}, 500)
        unless user then return res.json({error:'No user with that id'}, 404)

        if user.followingCauses?
          if req.form.idCause in user.followingCauses
            return res.json {error: 'User is already following that cause'}, 403
          else
            user.followingCauses.push req.form.idCause
        else
          user.followingCauses = [req.form.idCause]

        Users.update userId, {followingCauses: user.followingCauses}, (error, updatedUser) ->
          res.json {followingCauses: updatedUser.followingCauses}, 200

  followUser: (req, res) ->
    unless req.form.isValid
      req.json {errors: req.form.errors}, 422
    else
      userId = req.param('id')
      Users.find(userId).done (error, user) ->
        if error then return res.json({error}, 500)
        unless user then return res.json({error:'No user with that id'}, 404)

        if user.followingUsers?
          if req.form.idUser in user.followingUsers
            return res.json {error: 'User is already following that cause'}, 403
          else
            user.followingUsers.push req.form.idUser
        else
          user.followingUsers = [req.form.idUser]

        Users.update userId, {followingUsers: user.followingUsers}, (error, updatedUser) ->
          res.json {followingUsers: updatedUser.followingUsers}, 200

  feed: (req, res) ->
    userId = req.param('id')
    limitItems = req.param('limit') ? 0
    skipItems = req.param('skip') ? 0

    mUser = {} # define user out here, to use it inside serial tasks
    async.series(
      currentUser: (callback) ->
        Users.find(userId).done (err, user) ->
          mUser = user
          callback err, null

      feedCauses: (callback) ->
        Activities.findAll(
          supportsCause: mUser.followingCauses
        ).done callback

      feedUsers: (callback) ->
        Activities.findAll(
          author: mUser.followingUsers
        ).done callback
    ,
      (err, results)->
        feedObj = {}
        feedArr = []
        # Concatenate causes and users feed
        rawFeed = results.feedCauses.concat results.feedUsers
        # Remove repeated activities
        for activity in rawFeed
          feedObj[activity.id] = activity
        # From obj to array
        feedArr = (value for key, value of feedObj)
        # Sort array date DESC
        feedArr = feedArr.sort (a, b) ->
          a = new Date(a.createdAt)
          b = new Date(b.createdAt)
          if a < b then 1 else (if a > b then -1 else 0)

        res.json {feed: feedArr}
    )

module.exports = UsersController
