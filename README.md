# Backgammony [![Build Status](https://travis-ci.org/jonathanballs/backgammony.svg?branch=master)](https://travis-ci.org/jonathanballs/backgammony)
Backgammony is a backgammon client for Linux written with Dlang and GTK. It supports local AIs as well as trustless network games. It's targeted towards casual play and thus forgoes the analysis and tutor features present in other backgammon software in favor of a more streamlined and pleasant user interface.

![Screenshot](resources/screenshot.png)

## Artificial Intelligences
Backgammony currently only supports the GNU Backgammon artificial intelligence since there is no standard communication protocol like there is for chess. I am currently writing my own engine and will document the communication protocol thoroughly in an attempt to bring some standardisation to this area.

## Network Play
Backgammony brings an innovative approach to network play - predominantly where it has to generate dice rolls. The algorithm uses a basic [commitment scheme](https://en.wikipedia.org/wiki/Commitment_scheme) to ensure that dice rolls are non-interferable and games are trustless. To view the dice roll implementation please inspect the DiceRoll class in the [networking package](https://github.com/jonathanballs/backgammony/blob/master/source/networking/package.d).

## Building

Backgammony is written in the D language so make sure that you have a D compiler and the Dub package manager installed. Navigate to the project directory and run:

```
dub build && ./backgammon
# Or for flatpak (this installs gnubg inside the flatpak container)
flatpak-builder --install build-dir resources/linux/uk.jnthn.backgammon.json --force-clean --user
```

Make sure that you install GNU Backgammon installed if you wish to play against an AI as Backgammony does not have an AI currently.

### A historic event: The first backgammon game in its 5000 year history that was truly trustless
![FirstGame](resources/firstgame.jpg)

NB: The software crashed halfway through the game
