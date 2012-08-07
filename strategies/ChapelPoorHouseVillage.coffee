# Chapel away Coppers and Estates to enable $4 Poor Houses,
# buy Villages, and aim for double-PH turns for Province.
{
  name: 'ChapelPoorHouseVillage'
  requires: ['Chapel', 'Poor House', 'Village']
  gainPriority: (state, my) -> [
    # Open Village/Chapel. We can afford Poor Houses easily later,
    # and opening Village helps ensure we trash 4 cards.
    "Village" if my.countInDeck("Village") == 0 and my.turnsTaken <= 2
    "Chapel" if my.countInDeck("Chapel") == 0 and my.turnsTaken <= 2

    "Province"
    
    "Village" if my.countInDeck("Poor House") > my.countInDeck("Village")
    "Poor House"
  ]

  actionPriority: (state, my) -> [
    # The default plays Poor House instead of Chapel, even when we want to
    # trash.
    "Chapel" if wantsToTrash
  ]
}
