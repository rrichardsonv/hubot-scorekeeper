# Description:
#   Let hubot track your co-workers' honor points
#
# Configuration:
#   HUBOT_SCOREKEEPER_MENTION_PREFIX
#
# Commands:
#   <name>++ - Increment <name>'s point
#   <name>-- - Decrement <name>'s point
#   hubot scorekeeper - Show scoreboard
#   hubot show scoreboard - Show scoreboard
#   hubot scorekeeper <name> - Show current point of <name>
#   hubot what's the score of <name> - Show current point of <name>
#   hubot scorekeeper remove <name> - Remove current point of <name>
#   hubot reset scorekeper - Clear all points
#
# Author:
#   yoshiori

class Scorekeeper
  _prefix = "scorekeeper"

  comments =
    'increment': [
      ':sunglasses:',
      ':tada:',
      ':+1:',
      'Great!',
      'Congratulations!',
      ':heart_eyes:',
      'Full-scale',
      ':sparkles:',
      ':inb:',
      'well deserved',
      'kudos'
    ],
    'decrement': [
      ':broken_heart:',
      ':cry:',
      ':sbr_a:',
      ':sbr_b:',
      'Never mind!',
      'May the :happyturn: be with you',
    ]

  blacklist = [
    'xn'
  ]

  constructor: (@robot) ->
    @_loaded = false
    @_scores = {}
    @robot.brain.on 'loaded', =>
      @_load()
      @_loaded = true

  increment: (user, func) ->
    return if blacklist.indexOf(user) >= 0
    unless @_loaded
      setTimeout((=> @increment(user,func)), 200)
      return
    @_scores[user] = @_scores[user] or 0
    @_scores[user]++
    @_save()
    @score user, func

  decrement: (user, func) ->
    return if blacklist.indexOf(user) >= 0
    unless @_loaded
      setTimeout((=> @decrement(user,func)), 200)
      return
    @_scores[user] = @_scores[user] or 0
    @_scores[user]--
    @_save()
    @score user, func

  score: (user, func) ->
    func false, @_scores[user] or 0

  remove: (user, func) ->
    score = @_scores[user]
    delete @_scores[user]
    @_save()
    func false, score

  reset: (func) ->
    scores = @_scores
    scores_json = '{}'
    @_scores = JSON.parse scores_json
    @_save()
    func false, scores

  rank: (func)->
    current_rank = 0
    previous_rank = 0
    current_rank_score = undefined
    ranking = (for name, score of @_scores
      [name, score, 0]
    ).sort((a, b) -> b[1] - a[1]).map((a) ->
      current_rank++
      if current_rank_score == a[1]
        a[2] = previous_rank
      else
        a[2] = current_rank
      current_rank_score = a[1]
      previous_rank = a[2]
      a
    )

    func false, ranking

  pickComment: (event) ->
    candidates = comments[event]
    candidates[Math.floor(Math.random() * candidates.length)]

  _load: ->
    scores_json = @robot.brain.get _prefix
    scores_json = scores_json or '{}'
    @_scores = JSON.parse scores_json

  _save: ->
    scores_json = JSON.stringify @_scores
    @robot.brain.set _prefix, scores_json


module.exports = (robot) ->
  scorekeeper = new Scorekeeper robot
  mention_prefix = process.env.HUBOT_SCOREKEEPER_MENTION_PREFIX
  if mention_prefix
    mention_matcher = new RegExp("^#{mention_prefix}")

  userName = (user) ->
    user = user.trim().split(/\s/).slice(-1)[0]
    if mention_matcher
      user = user.replace(mention_matcher, "")
    user

  sendRanking = (msg, result) ->
    msg.send (for r in result
      "#{r[0]} (#{r[1]}pt)"
    ).join("\n")

  robot.hear /[^+-]{2,}\+{5,}(?:\s|$)/g, (msg) ->
    great = "☆o｡:･;;.｡:*･☆o｡:･;;.｡:*･☆o｡:･;;.｡:*･☆o｡:･;;.｡:*･☆o｡:･;;.｡:*･☆"
    for str in msg.match
      user = userName(str.replace(/\+/g, '').toLowerCase())
      scorekeeper.increment user, (error, result) ->
        msg.send "#{great}\n#{scorekeeper.pickComment('increment')} #{user}\n#{great}"

  robot.hear /[^+-]{2,}\+{2,4}(?:\s|$)/g, (msg) ->
    for str in msg.match
      user = userName(str.replace(/\+/g, '').toLowerCase())
      scorekeeper.increment user, (error, result) ->
        msg.send "#{scorekeeper.pickComment('increment')} #{user}"

  robot.hear /[^+-]{2,}\-{2,}(?:\s|$)/g, (msg) ->
    for str in msg.match
      user = userName(str.replace(/-/g, '').toLowerCase())
      scorekeeper.decrement user, (error, result) ->
        msg.send "#{scorekeeper.pickComment('decrement')} #{user}"

  robot.hear /[OＯ][KＫ](牧場|B|Ｂ)/g, (msg) ->
    user = msg.message.user.name
    scorekeeper.decrement user, (error, result) ->
      msg.send ":sbr_a: #{scorekeeper.pickComment('decrement')} #{user} :sbr_b:"

  robot.respond /scorekeeper$|show(?: me)?(?: the)? (?:scorekeeper|scoreboard)$/i, (msg) ->
    scorekeeper.rank (error, result) ->
      sendRanking(msg, result)

  robot.respond /scorekeeper remove (.+)$/i, (msg) ->
    user = userName(msg.match[1])
    scorekeeper.remove user, (error, result) ->
      msg.send "#{user} has been removed. (#{result} pt)"

  robot.respond /reset scorekeeper$/i, (msg) ->
    scorekeeper.reset (error, result) ->
      msg.send "\n===== Scorekeeper is reset ====="

  robot.respond /scorekeeper (.+)$|what(?:'s| is)(?: the)? score of (.+)\??$/i, (msg) ->
    user = userName(msg.match[1] || msg.match[2])
    scorekeeper.score user, (error, result) ->
      msg.send "#{user} has #{result} points"
