# The Basic AI
# ------------
# This class defines a rule-based AI of the kind that is popular
# for evaluating Dominion strategies. It can be subclassed -- or simply
# have its methods overwritten on an instance -- to play new strategies.
#
# Every time the player needs to make a meaningful decision, a method called
# `chooseX` (for some X) will be called on the AI, which can examine the game
# state and make a decision accordingly.
#
# In any case that is not a simple yes/no decision, the method will be 
# given a list of choices. It will delegate to the `xValue` method to assign a
# value to each possible choice, and choose the one with the highest value
# (earlier options win ties).
#
# If the `xValue` method does not exist (as will often be the case), it will
# try a different method called `xPriority`, which takes in the state and
# returns an ordered list of choices. The player will make the first valid
# choice in that list. Priority functions are usually easier to define than
# value functions.
#
# The BasicAI has a default decision function for every decision, so
# every AI that derives from it will have *some* way to decide what to do in
# any situation. However, when defining an AI, you will often want to override
# some of these decision functions.
class BasicAI
  name: 'Basic AI'
  author: 'rspeer'

  # Referring to `state.current` to find information about one's own state is
  # not always safe! Some of these decisions may be made during other players'
  # turns. In those cases, what we want is `this.myPlayer(state)`.
  #
  # This is passed in as an argument `my` to the decision functions, because
  # it's convenient and it creates nice idioms such as `my.hand`.
  myPlayer: (state) ->
    for player in state.players
      if player.ai is this
        return player
    throw new Error("#{this} is being asked to make a decision, but isn't playing the game...?")

  # Decision-making machinery
  # -------------------------
  # Make the AI's preferred choice, first by checking its explicit priority
  # list. If no valid choices are on the list, ask the value function instead.
  #
  # The priority function returns an ordered list of choices it will want to
  # make when they are available. If 'null' is on the priority list, that
  # represents an explicit preference to choose "none of the above" when it's
  # an option.
  #
  # The value list assigns a numerical value to every possible choice. 'null'
  # automatically has a value of 0. Here you can represent actions you will
  # only take when forced to, by giving them negative values.
  #
  # If a choice should be made entirely using the value function, make the
  # priority function return an empty list.
  #
  # This function replaces two older functions called `choosePriority` and
  # `chooseValue`.
  chooseByPriorityAndValue: (state, choices, priorityfunc, valuefunc) ->
    my = this.myPlayer(state)
    
    # Are there no choices? We follow the rule that makes the null choice
    # available in that situation, and choose it.
    if choices.length == 0
      return null

    # First, try the priority function. If the priority function reaches
    # the end of its list, it is treated as "none of the above".
    if priorityfunc?
      # Construct an object with the choices as keys, so we can look them
      # up quickly.
      choiceSet = {}
      for choice in choices
        choiceSet[choice] = choice
      
      # Get the priority list.
      priority = priorityfunc(state, my)
      # Now look up all the preferences in that list. The moment we encounter
      # a valid choice, we can return it.
      for preference in priority
        if preference is null and null in choices
          return null
        if choiceSet[preference]?
          return choiceSet[preference]
  
    # The priority list doesn't want any of these choices (perhaps because
    # it doesn't exist). Now try the value list.
    if valuefunc?
      bestChoice = null
      bestValue = -Infinity
    
      for choice in choices
        if (choice is null) or (choice is no)
          value = 0
        else
          value = valuefunc(state, choice, my)
        if value > bestValue
          bestValue = value
          bestChoice = choice
      
      # If we got a valid choice, return it.
      if bestChoice in choices
        return bestChoice
    
    # If we get here, the AI probably wants to choose none of the above.
    if null in choices
      return null
    
    # Hmm. None of the above isn't an option, and neither the priority list nor
    # the value list gave us anything. First complain about it, then make an
    # arbitrary choice.
    state.warn("#{this} has no idea what to choose from #{choices}")
    return choices[0]
  
  # Sometimes we need to compare choices in a strictly numeric way. This takes
  # a particular choice for a particular choice type, and gets its numeric value.
  # If the value comes from a priority list, it will be 1000 - (index in list).
  #
  # So, for example, the default choiceToValue of discarding a Colony is 999, while
  # the choiceToValue of discarding an extra terminal is 1.
  choiceToValue: (type, state, choice) ->
    return 0 if choice is null
    my = this.myPlayer(state)
    priorityfunc = this[type+'Priority']
    valuefunc = this[type+'Value']
    if priorityfunc?
      priority = priorityfunc(state, my)
    else
      priority = []

    index = priority.indexOf(stringify(choice))
    if index != -1
      return (priority.length - index) * 100
    else if valuefunc?
      return valuefunc(state, choice, my)
    else
      return 0
 
  # The top-level "choose" function takes a decision type, the current state,
  # and a list of choices. It delegates to other functions with the appropriate
  # names automatically: for example, if the type is 'foo', the AI will check
  # its fooValue and fooPriority functions.
  choose: (type, state, choices) ->
    # Get the priority and value functions. If one doesn't exist, that's okay,
    # we'll pass on the 'undefined' value and chooseByPriorityAndValue will
    # know what to do.
    priorityfunc = this[type+'Priority']
    valuefunc = this[type+'Value']
    this.chooseByPriorityAndValue(state, choices, priorityfunc, valuefunc)
  
  #### Backwards-compatible choices
  # 
  # To avoid having to rewrite all the code at once, we support these functions
  # that pass `chooseAction` onto `choose('action')`, and so on.
  chooseAction: (state, choices) -> this.choose('action', state, choices)
  chooseTreasure: (state, choices) -> this.choose('treasure', state, choices)
  chooseGain: (state, choices) -> this.choose('gain', state, choices)
  chooseDiscard: (state, choices) -> this.choose('discard', state, choices)
  chooseTrash: (state, choices) -> this.choose('trash', state, choices)

  # Default strategies
  # ------------------
  # The default buying strategy is a form of Big Money that has, by now,
  # been beaten by the newer one in BigMoney.coffee.
  gainPriority: (state, my) -> [
    "Colony" if my.countInDeck("Platinum") > 0
    "Province" if state.countInSupply("Colony") <= 6
    "Duchy" if 0 < state.gainsToEndGame() <= 5
    "Estate" if 0 < state.gainsToEndGame() <= 2
    "Platinum"
    "Gold"
    "Silver"
    "Copper" if state.gainsToEndGame() <= 3
  ]
  
  # The default action-playing strategy, which aims to include a usable plan
  # for playing every action card, so that most AIs don't need to override it.
  actionPriority: (state, my) -> [
    # First priority: cards that succeed if we play them now, and might
    # not if we play them later.
    "Menagerie" if my.menagerieDraws() == 3
    "Shanty Town" if my.shantyTownDraws(true) == 2
    "Tournament" if my.countInHand("Province") > 0
    # Second priority: cards that stack the deck.
    "Lookout" if state.gainsToEndGame() >= 5 or state.cardInfo.Curse in my.draw
    "Bag of Gold"
    "Apothecary"
    "Scout"
    # Third priority: cards that give +2 actions.
    "Trusty Steed"
    "Festival"
    "University"
    "Farming Village"
    "Bazaar"
    "Worker's Village"
    "City"
    "Walled Village"
    "Fishing Village"
    "Village"
    # Fourth priority: cards that give +1 action and are almost always good.
    "Grand Market"
    "Hunting Party"
    "Alchemist"
    "Laboratory"
    "Caravan"
    "Market"
    "Peddler"
    "Treasury"
    "Conspirator" if my.inPlay.length >= 2
    "Familiar"
    "Great Hall"
    "Wishing Well"
    "Lighthouse"
    # Fifth priority: terminal card-drawers, if we have actions to spare.
    "Library" if my.actions > 1 and my.hand.length <= 4
    "Rabble" if my.actions > 1
    "Smithy" if my.actions > 1
    "Watchtower" if my.actions > 1 and my.hand.length <= 4
    "Library" if my.actions > 1 and my.hand.length <= 5
    "Courtyard" if my.actions > 1 and my.hand.lenth <= 3
    # Sixth priority: card-cycling that might improve the hand.
    "Upgrade" if my.ai.wantsToTrash(state)
    "Pawn"
    "Warehouse"
    "Cellar"
    "Library" if my.actions > 1 and my.hand.length <= 6
    # Seventh priority: non-terminal cards that don't succeed but at least
    # give us something.
    "Tournament"
    "Menagerie"
    "Shanty Town" if my.actions < 2
    # Seventh priority: terminals. Of course, Nobles might be a non-terminal
    # if we decide we need the actions more than the cards.
    "Nobles"
    "Treasure Map" if my.countInHand("Treasure Map") >= 2
    "Followers"
    "Mountebank"
    "Witch"
    "Torturer"
    "Sea Hag"
    "Tribute" # after Cursers but before other terminals, there is probably a better spot for it
    "Goons"
    "Wharf"
    # Tactician needs a play condition, but I don't know what it would be.
    "Tactician"
    "Masquerade"
    "Vault"
    "Princess"
    "Explorer" if my.countInHand("Province") >= 1
    "Library" if my.hand.length <= 3
    "Expand"
    "Remodel"
    "Militia"
    "Cutpurse"
    "Bridge"
    "Horse Traders"
    "Steward"
    "Moneylender" if my.countInHand("Copper") >= 1
    "Mine"
    "Coppersmith" if my.countInHand("Copper") >= 3
    "Library" if my.hand.length <= 4
    "Rabble"
    "Smithy"
    "Watchtower" if my.hand.length <= 3
    "Council Room"
    "Library" if my.hand.length <= 5
    "Watchtower" if my.hand.length <= 4
    "Courtyard" if my.hand.length > 0
    "Merchant Ship"
    "Baron" if my.countInHand("Estate") >= 1
    "Monument"
    "Remake"   # has a low priority so it'll mostly be played early in the game
    "Adventurer"
    "Harvest"
    "Explorer"
    "Woodcutter"
    "Chancellor"
    "Counting House"
    "Coppersmith" if my.countInHand("Copper") >= 2
    "Outpost" if state.extraturn == false
    # Play an Ambassador if our hand has something we'd want to discard.
    #
    # Here the AI has to refer to itself indirectly, as `my.ai`. `this`
    # actually has the wrong value right now because JavaScript is weird.
    "Ambassador" if my.ai.wantsToTrash(state)
    "Trading Post" if my.ai.wantsToTrash(state) + my.countInHand("Silver") >= 2
    "Chapel" if my.ai.wantsToTrash(state)
    "Trade Route" if my.ai.wantsToTrash(state)
    "Mint" if my.ai.choose('mint', state, my.hand)
    "Bureaucrat"
    "Conspirator" if my.actions < 2
    "Herbalist"
    "Moat"
    "Library" if my.hand.length <= 6
    "Watchtower" if my.hand.length <= 5
    "Ironworks" # should have higher priority if condition can see it will gain an Action card
    "Workshop"
    "Smugglers" if state.smugglerChoices().length > 1
    "Coppersmith"
    "Library" if my.hand.length <= 7
    # Eighth priority: cards that have become useless. Maybe they'll decrease
    # the cost of Peddler, trigger Conspirator, or something.
    "Treasure Map" if my.countInDeck("Gold") >= 4 and state.current.countInDeck("Treasure Map") == 1
    "Shanty Town"
    "Chapel"
    "Library"
    # Ninth priority: Conspirator when +actions remain.
    "Conspirator"
    # At this point, we take no action if that choice is available.
    null
    # Nope, something is forcing us to take an action.
    #
    # Last priority: cards that are actively harmful to play at this point,
    # in order of increasing badness.
    "Watchtower"
    "Trade Route"
    "Treasure Map"
    "Ambassador"
  ]
  
  # Most of the order of `treasurePriority` has no effect on gameplay. The
  # important part is that Bank and Horn of Plenty are last.
  treasurePriority: (state, my) -> [
    "Platinum"
    "Diadem"
    "Philosopher's Stone"
    "Gold"
    "Hoard"
    "Royal Seal"
    "Harem"
    "Venture"
    "Silver"
    "Quarry"
    "Copper"
    "Potion"
    "Bank"
    "Horn of Plenty" if my.numUniqueCardsInPlay() >= 2
  ]

  # Perhaps not the fastest way, but most fun
  # Also perhaps redundant to chooseOrderOnDeck
  sortByPriority: (list,state, my) =>
    list.sort( (l) ->  (index for v, index in my.ai.actionPriority(state, my)).reduce (a,b) -> Math.min(a,b) )

  # `chooseOrderOnDeck` handles situations where multiple cards are returned
  # to the deck, such as Scout and Apothecary.
  #
  # This decision doesn't fit into the xPriority / xValue framework, as there
  # are a number of mostly indistinguishable choices. Instead of listing all
  # the permutations of cards as choices, we just list the cards to arrange.
  #
  # The default decision is to put the cards with the lowest discard value on
  # top.
  chooseOrderOnDeck: (state, cards, my) ->
    sorter = (card1, card2) ->
      my.ai.choiceToValue('discard', state, card1)\
      - my.ai.choiceToValue('discard', state, card2)
    
    choice = cards.slice(0)
    return choice.sort(sorter)

  mintValue: (state, card, my) -> 
    # Mint anything but coppers. Otherwise, go mostly by the card's base cost.
    # Diadems are comparable to the cost-5 treasures.
    if card is 'Diadem'
      return 4
    return card.cost - 1
  
  # The default `discardPriority` is tuned for Big Money where the decisions
  # are obvious. But many strategies would probably prefer a different
  # priority list, especially one that knows about action cards.
  #
  # It doesn't understand
  # discarding cards to make Shanty Town or Menagerie work, for example.
  discardPriority: (state, my) -> [
    "Vineyard"
    "Colony"
    "Duke"
    "Duchy"
    "Gardens"
    "Province"  # Provinces are occasionally useful in hand
    "Curse"
    "Estate"
  ]

  discardValue: (state, card, my) =>
    # If we can discard excess actions, do so. Otherwise, discard the cheapest
    # cards. Victory cards would already have been discarded by discardPriority.
    if (card.actions == 0 and my.actionBalance() <= 0) or (my.actions == 0)
      20 - card.cost
    else
      0 - card.cost
  
  # Changed Priorities for putting cards back on deck.  Only works well for putting back 1 card, and for 1 buy.
  #
   putOnDeckPriority: (state, my) -> 
    putBack = []
    # 1) If no actions left, put back best Action
    #    Take card from hand which are actions, sort them by ActionPriority
    #
    if my.countPlayableTerminals(state) == 0
      putBack = (card for card in my.hand when card?.isAction).sort( (y, x) -> my.ai.choiceToValue('action', state, x) - my.ai.choiceToValue('action', state, y) ) 
      
    # 2) If not enough actions left, put back best Terminal you can't play
    #    Take cards from hand which are Actions and Terminals, sort them by ActionPriority
    #    Then, ignore as many terminals as you can play this turn, return the others
    #
    else
      putBack = (tmp=( card for card in my.hand when (card?.isAction and card?.getActions(state)>0) ).sort( (y, x) -> my.ai.choiceToValue('action', state, x) - my.ai.choiceToValue('action', state, y) ) )[my.countPlayableTerminals(state) ... tmp.length]
      
    # 3) Put back as much money as you can
    #    First get a pessimistic estimate of the avaiable money this turn
    #    then find take the cost in coins of the highest priority card you can afford
    #    then put the treasures which are not needed in 'putBack' for discardPriority, most valuable first, Potion = 2.5 Coins
    #
    if putBack.length==0
      coinEstimate = my.ai.pessimisticMoneyInHand(state)
      potionEstimate = my.countInHand(state.cardInfo["Potion"])
      
      [coinTarget, potionTarget] = ([state.cardInfo[card]?.getCost(state)[0], state.cardInfo[card]?.getCost(state)[1] ] for card in my.ai.gainPriority(state, my) when ( (state.cardInfo[card]?.getCost(state)[0] <= coinEstimate) and (state.cardInfo[card]?.getCost(state)[1] <= potionEstimate )) )
      
      if coinTarget? and coinTarget.length? and coinTarget>0
        coinTarget = coinTarget[0]
      else 
        coinTarget = 0
        
      if potionTarget? and potionTarget.length? and potionTarget.length>0
        potionTarget = potionTarget[0]
      else
        potionTarget = 0
    
      # Don't put last Potion back if Alchemists are in play
      #
      if (my.countInPlay(state.cardInfo["Alchemist"]) > 0)
        potionTarget = Math.max potionTarget, 1
      
      putBack = (card for card in my.hand when (card.isTreasure and (card.getCoins(state) <= (coinEstimate - coinTarget)) and (card.getPotion(state) <= (potionEstimate - potionTarget)) ) ).sort( (b, a) -> (state.cardInfo[a].getCoins(state) + 2.5*state.cardInfo[a].getPotion(state) - state.cardInfo[b].getCoins(state) - 2.5*state.cardInfo[b].getPotion(state)) )
         
    # 4) Put back the worst card (take priority for discard)
    #
    if putBack.length==0
      putBack = (card for card in my.ai.discardPriority(state, my) when (state.cardInfo[card] in my.hand) )
    putBack
  
  putOnDeckValue: (state, card, my) =>
    this.discardValue(state, card, my)
  
  # The `herbalist` decision puts a treasure card back on the deck. It sounds
  # the same as `putOnDeck`, but it's for a different
  # situation -- the card is coming from in play, not from your hand. So
  # actually we use the `mintValue` by default.
  herbalistValue: (state, card, my) =>
    this.mintValue(state, card, my)

  trashPriority: (state, my) -> [
    "Curse"
    "Estate" if state.gainsToEndGame() > 4
    "Copper" if my.getTotalMoney() > 4
    "Potion" if my.turnsTaken >= 10
    "Estate" if state.gainsToEndGame() > 2
  ]

  # If we have to trash a card we don't want to, assign a value to each card.
  # By default, we want to trash the card with the lowest (cost + VP).
  trashValue: (state, card, my) ->
    0 - card.vp - card.cost

  # When presented with a card with simple but variable benefits, such as
  # Nobles, this is the default way for an AI to decide which benefit it wants.
  # This function should actually handle a number of common situations.
  benefitValue: (state, choice, my) ->
    buyValue = 1
    cardValue = 2
    coinValue = 3
    trashValue = 4      # if there are cards we want to trash
    actionValue = 10    # if we need more actions

    actionBalance = my.actionBalance()
    usableActions = Math.max(0, -actionBalance)

    if actionBalance >= 1
      cardValue += actionBalance
    if my.ai.wantsToTrash(state) < (choice.trash ? 0)
      trashValue = -4
    
    value = cardValue * (choice.cards ? 0)
    value += coinValue * (choice.coins ? 0)
    value += buyValue * (choice.buys ? 0)
    value += trashValue * (choice.trash ? 0)
    value += actionValue * Math.min((choice.actions ? 0), usableActions)
    #state.log("Benefit: #{JSON.stringify(choice)} / Value: #{value} / wants to trash: #{my.ai.wantsToTrash(state)}")
    value
    
  # `ambassadorPriority` chooses a card to Ambassador and how many of it to
  # return.
  #
  # These choices may look odd: remember that choices are evaluated as strings.
  # So if we return lists, they won't match any of the choices. We need to
  # return their joined string versions.
  #
  # This is a moderately acceptable way to deal with the fact that, in
  # JavaScript, lists are never "equal" to other lists anyway.
  ambassadorPriority: (state, my) ->
    [
      "Curse,2"
      "Curse,1"
      "Curse,0"
      # Handle a silly case:
      "Ambassador,2"
      "Estate,2"
      "Estate,1"
      # Make sure we have at least $5 in the deck, including if we buy a Silver.
      "Copper,2" if my.getTreasureInHand() < 3 and my.getTotalMoney() >= 5
      "Copper,2" if my.getTreasureInHand() >= 5
      "Copper,2" if my.getTreasureInHand() == 3 and my.getTotalMoney() >= 7
      "Copper,1" if my.getTreasureInHand() < 3 and my.getTotalMoney() >= 4
      "Copper,1" if my.getTreasureInHand() >= 4
      "Estate,0"
      "Copper,0"
    ]
  
  # Taking into account gain priorities, gain values, trash priorities, and
  # trash values, how much do we like having this card in our deck overall?
  cardInDeckValue: (state, card, my) ->
    endgamePower = 1
    
    # Are we in the late game? If so, we care much more about getting cards
    # at the top of our priority order.
    if state.gainsToEndGame() <= 5
      endgamePower = 3

    return -(this.choiceToValue('trash', state, card)) + \
           Math.pow(this.choiceToValue('gain', state, card), endgamePower)

  # upgradeValue measures the benefit of choices on Remodel, Upgrade,
  # and so on, where you exchange one card for a better one.
  # 
  # So here's a really basic thing that might work.
  upgradeValue: (state, choice, my) ->
    [oldCard, newCard] = choice
    return my.ai.cardInDeckValue(state, newCard, my) - \
           my.ai.cardInDeckValue(state, oldCard, my)
  
  # The question here is: do you want to discard an Estate using a Baron?
  # And the answer is yes.
  baronDiscardPriority: (state, my) -> [yes]

  # `wishValue` prefers to wish for the card its draw pile contains
  # the most of.
  #
  # The fact that this doesn't make a hypothetical copy is a shortcut. We are
  # technically "peeking" at the deck, but we don't use any information except
  # the count of each card, which would be the same in any hypothetical version.
  wishValue: (state, card, my) ->
    pile = my.draw
    if pile.length == 0
      pile = my.discard
    return countInList(pile, card)
  
  # Prefer to gain action and treasure cards on the deck. Give other cards
  # a value of -1 so that `null` is a better choice.
  gainOnDeckValue: (state, card, my) ->
    if (card.isAction or card.isTreasure)
      1
    else
      -1
  
  # How much does the AI want to discard its deck right now (for Chancellor)?
  # Here, we decide to reshuffle (returning a reshuffleValue over 0) when most
  # of the non-Action, non-Treasure cards are in the draw pile, or when there
  # are no such cards in the deck.
  reshuffleValue: (state, choice, my) ->
    junkToDraw = 0
    totalJunk = 0
    for card in my.draw
      if not (card.isAction or card.isTreasure)
        junkToDraw++
    for card in my.getDeck()
      if not (card.isAction or card.isTreasure)
        totalJunk++
    return 1 if (totalJunk == 0)
    proportion = junkToDraw/totalJunk
    return (proportion - 0.5)

  # Choose to discard or to gain a curse when attacked by Torturer.
  torturerPriority: (state, my) -> [
    'curse' if state.countInSupply("Curse") == 0
    'discard' if my.ai.wantsToDiscard(state) >= 2
    'discard' if my.hand.length <= 1
    'curse' if my.trashingInHand() > 0
    'curse' if my.hand.length <= 3
    'discard'
    'curse'
  ]

  librarySetAsideValue: (state, card, my) -> [
    if my.actions == 0 and card.isAction
      1
    else
      -1
  ]

  #### Informational methods
  #
  # `wantsToTrash` returns the number of cards in hand that we would trash
  # for no benefit.
  wantsToTrash: (state) ->
    my = this.myPlayer(state)
    trashableCards = 0
    for card in my.hand
      if this.chooseTrash(state, [card, null]) is card
        trashableCards += 1
    return trashableCards
  
  # `wantsToDiscard` returns the number of cards in hand that we would
  # freely discard.
  wantsToDiscard: (state) ->
    my = this.myPlayer(state)
    discardableCards = 0
    for card in my.hand
      if this.chooseDiscard(state, [card, null]) is card
        discardableCards += 1
    return discardableCards

  # `pessimisticMoneyInHand` establishes a minimum on how much money the
  # player will be able to spend in this game state. It assumes the player
  # will draw no money from the deck.
  pessimisticMoneyInHand: (state) ->
    # Don't recurse more than once. If we're already in a hypothetical
    # situation, use the stupid version instead.
    if state.depth > 0
      return this.myPlayer(state).getAvailableMoney()

    buyPhase = this.pessimisticBuyPhase(state)
    return buyPhase.current.coins
  
  # Look ahead to the buy phase, assuming we draw no money from the deck.
  #
  # TODO: when we can handle known cards on top of the deck, take them
  # into account.
  pessimisticBuyPhase: (state) ->
    if state.depth > 0
      # A last-ditch effort to avoid recursion, by simply fast-forwarding
      # to the next phase.
      if state.phase == 'action'
        state.phase = 'treasure'
      else if state.phase == 'treasure'
        state.phase = 'buy'

    [hypothesis, hypothetically_my] = state.hypothetical(this)
    hypothetically_my.draw = []
    hypothetically_my.discard = []
    
    while hypothesis.phase != 'buy'
      hypothesis.doPlay()

    return hypothesis
  
  pessimisticCardsGained: (state) ->
    newState = this.pessimisticBuyPhase(state)
    newState.doPlay()
    return newState.current.gainedThisTurn

  #### Utility methods
  #
  # `copy` makes a copy of the AI. It will have the same behavior but a
  # different name, and will not be equal to this AI.
  copy: () ->
    ai = new BasicAI()
    for key, value of this
      ai[key] = value
    ai.name = this.name+'*'
    ai

  toString: () -> this.name
this.BasicAI = BasicAI

# Utility functions
# -----------------
# `count` counts the number of times `elt` appears in `list`.
countInList = (list, elt) ->
  count = 0
  for member in list
    if member == elt
      count++
  count

# `stringify` turns an object into a string, while handling `null` safely.
stringify = (obj) ->
  if obj is null
    return null
  else
    return obj.toString()

