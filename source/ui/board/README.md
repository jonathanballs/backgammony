# Backgammon Board Design Overview

Despite being only a single widget, the board is one of the most important and
complicated pieces of code in the codebase. Its architecture has been thought
about very carefully.

Separation of Concerns is one of the most important software design principles
so it was decided that the backgammon board should not need to understand any
of the rules of a game of backgammon.

* It should purely think about animations and handling user interaction.
* Animations should queue instead of cutting when changes occur.
* Animations should be queueable programmatically.
* Animation speed should be variable - speeding up when animation queue is long
