Feature: Sending messages

  Scenario: Brainstorming
    Given fred registered as user "fred@127.0.0.1" with nick "fred"
      And I registered as user "Emmanuel@127.0.0.1" with nick "Emmanuel"
      And fred JOIN "#retro"
      And I JOIN "#retro"

    When I send "PRIVMSG" with:
      | target | #retro |
      | body   | .bstorm |
    And I send "PRIVMSG" with:
      | target | #retro |
      | body   | * One Item |
    And fred send "PRIVMSG" with:
      | target | #retro |
      | body   | * Another Item |
    And fred send "PRIVMSG" with:
      | target | #retro |
      | body   | * Yet Another Item |

    And I send "PRIVMSG" with:
      | target | #retro |
      | body   | .endstorm |
    And I send "PRIVMSG" with:
      | target | #retro |
      | body   | .list |

    Then I should receive "PRIVMSG" with:
      | body   | [[[ 0 ]]] One Item |
    And I should receive "PRIVMSG" with:
      | body   | [[[ 1 ]]] Another Item |

  Scenario: Merging
    Given I registered as user "Emmanuel@127.0.0.1" with nick "Emmanuel"
      And I JOIN "#retro"
      And I send "PRIVMSG" with:
        | target | #retro |
        | body   | .bstorm |
      And I send "PRIVMSG" with:
        | target | #retro |
        | body   | * One Item |
      And I send "PRIVMSG" with:
        | target | #retro |
        | body   | * Other Item |
      And I send "PRIVMSG" with:
        | target | #retro |
        | body   | * Another Item |

    When I send "PRIVMSG" with:
      | target | #retro |
      | body   | .merge 0, 2|
    And I send "PRIVMSG" with:
      | target | #retro |
      | body   | .list |

    Then I should receive "PRIVMSG" with:
      | body   | [[[ 1 ]]] Other Item |
    And I should receive "PRIVMSG" with:
      | body   | [[[ 3 ]]] One Item / Another Item |

  Scenario: Voting
    Given fred registered as user "fred@127.0.0.1" with nick "fred"
      And I registered as user "Emmanuel@127.0.0.1" with nick "Emmanuel"
      And fred JOIN "#retro"
      And I JOIN "#retro"

      And I send "PRIVMSG" with:
        | target | #retro |
        | body   | .bstorm |

      And fred send "PRIVMSG" with:
        | target | #retro |
        | body   | * Another Item |
      And fred send "PRIVMSG" with:
        | target | #retro |
        | body   | * Yet Another Item |
      And I send "PRIVMSG" with:
        | target | #retro |
        | body   | * One Item |

      And I send "PRIVMSG" with:
        | target | #retro |
        | body   | .endstorm |

    When I send "PRIVMSG" with:
      | target | #retro |
      | body   | votes:0,1,1 |
      And fred sends "PRIVMSG" with:
        | target | #retro |
        | body   | votes:0,2,1 |

    Then I should receive "PRIVMSG" with:
      | body   | With 3 votes: 1 |
    And I should receive "PRIVMSG" with:
      | body   | With 2 votes: 0 |
    And I should receive "PRIVMSG" with:
      | body   | With 1 votes: 2 |
