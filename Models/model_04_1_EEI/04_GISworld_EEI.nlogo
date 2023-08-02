extensions [
  csv
  gis
  rnd
]


globals [
  ;gloabals to be set before the simulation
  stop_time                                     ; how many ticks the simulation will run (one tick = one day)
  parameter_a                                   ; parameter that weights the utility of catch and distance
  catch_utility_b                               ; parameter to set the linear increase of the catch utility
  dist_utility_b                                ; parameter to set the linear decrease of the distance utility
  parameter_e                                   ; parameter that decides the probaility if a new spot is explored or a spot is chosen based on the utlity

  ; globals that are updated during the simulation
  number_angler       ; is generated with csv
  number_locations    ; is generated with csv
  total_trips         ; total trips of all angler agents togehter
  total_catch         ; total catch of all angler agents togehter

  ; dummy variables within fuctions or to check R connection
  current_angler      ; variable to safe the who of the current angler, to use it in a function
  current_location    ; variable to safe the who of the current location, to use it in a function
  test_a
  test_e


  country_dataset
  angler_dataset
  spot_dataset
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;                          Agents/Turtels                      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; angler and locations are turtles (agents)
breed [ angler a-angler]
breed [ locations location]

angler-own [
  ; generated by csv
  homelocation_name
  homelocation_name_short
  homelocation_x
  homelocation_y
  max_distance
  fishing_method
  random_angler_nr

  ; generated during the simulation
  number_friends
  chosen_location         ; variable to safe the last chosen location
  total_angler_trips      ; total number of fishing trips
  total_traveled_dist     ; total distance a angler traveld for the fishing trips
  daily_angler_catch      ; catch at this tick
  total_angler_catch      ; total catch of the whole simulation of a angler
]

locations-own [
  ; generated by csv
  location_name
  location_x
  location_y
  location_method
  CPUE_mean
  CPUE_sd
  prob_over_mean

  ; generated during the simulation
  visited                 ; True/false variable if the location was visited
  total_visits            ; total number of fishing trips during the whole simulation to this location
  total_location_catch    ; total catch during the whole simulation at this location
]


; a special link between fishing locations and angler homelocation that contains the distance
undirected-link-breed [connections connection]

connections-own [
  distances
]


; a other link that specify a social network
undirected-link-breed [friends friend]

friends-own [
  friendship
]





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;                          Setup of the model                      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to setup
  clear-all
  file-close-all ; Close any files open from last run

  ;set globals
  set stop_time 365
  set parameter_a value-of-parameter_a              ; parameter that determines the ratio of the distance- and catch-utility of the total utility from a location, value set over the slider "value-of-parameter_a"
  set catch_utility_b value-of-catch_utility_b      ; parameter that determines the increase of the catch utility, normally 1 / 9 = 9 corresponde to the maximum expected catch of a location which results in the highest utility
  set dist_utility_b value-of-dist_utility_b        ; parameter that determines the decrease of the distance utility, normally 1 / 511 = 511 corresponde to the maximum distance from a homelocation to a fishing location which result in the lowest utility
  set parameter_e value-of-parameter_e              ; parameter that decides the probaility if a new spot is explored or a spot is chosen based on the utlity, value set over the slider "value-of-parameter_b"


  set country_dataset gis:load-dataset "gis_data/Bundeslaender/Bundeslaender.shp"
  set angler_dataset gis:load-dataset "gis_data/angler_complex/angler_complex.shp"
  set spot_dataset gis:load-dataset "gis_data/accesspoints/accesspoints_pt.shp"
  gis:set-world-envelope (gis:envelope-union-of (gis:envelope-of angler_dataset)
                                                (gis:envelope-of spot_dataset)
                                                (gis:envelope-of country_dataset))

  ; create map
  gis:set-drawing-color white
  gis:fill country_dataset 1

  ask patches [set pcolor gray ] ; set the backgound to gray


  setup-locations
  setup-angler
  setup-connections
  setup-friends

  reset-ticks
end



; set up the locations with gis
to setup-locations
  gis:create-turtles-from-points-manual spot_dataset locations
  [["ap_code" "location_name"]["fishing_me" "location_method"]["average_ca" "CPUE_mean"]["sd_catch" "CPUE_sd"]["perc_trips" "prob_over_mean"]]
  [
    set color black
    set size 0.2
    set shape "square"

    ;when we want different colored symbols for the location
;    (ifelse
;      location_method = "Kutter" [set color green]
;      location_method = "Boot" [set color red]
;      location_method = "Land" [set color blue]
;      [set color black])

    set location_x xcor
    set location_y ycor
    set visited false
  ]

  set number_locations count locations
end

; set up the angler with gis
to setup-angler
  gis:create-turtles-from-points-manual angler_dataset angler
  [["zip_code" "homelocation_name"]["max_distan" "max_distance"]["fishing_me" "fishing_method"]]
  [
    set color black
    set size 0.2
    set shape "person"

    (ifelse
      fishing_method = "Kutter" [set color green]
      fishing_method = "Boot" [set color red]
      fishing_method = "Land" [set color blue]
      [set color black])

    set homelocation_name_short precision homelocation_name -2          ; round the home location to the first three digits, e.g. 11111 -> 11100
    set homelocation_x xcor
    set homelocation_y ycor
  ]

  set number_angler count angler
end


to setup-connections                                                                   ; connections represent the distance between the homelocations and the fishing locations
  file-open "distances.csv"
  let row csv:from-row file-read-line
  while [ not file-at-end? ] [
    let zip item 0 row
    let loc item 1 row
    let dis item 2 row

    ask angler with [homelocation_name = zip][
      create-connections-with locations with [location_name = loc] [
        set distances dis]
    ]

    set row (csv:from-row file-read-line)
  ]
  file-close; make sure to close the file

  ask connections [
    hide-link
  ]
end


to setup-friends
  ask angler [
    let home_name homelocation_name
    let method fishing_method
    create-friends-with other angler with [homelocation_name = home_name AND fishing_method = method] [                ; friends only occure in the same homelocation, which lead to the same distances to the fishing locations
      set friendship 1
    ]

    let limit 15                                                                                                       ;limit the number of friends to 15 in accordance with the off-site data from 2021
    if (count my-friends > limit) [
      ask n-of (count my-friends - limit) my-friends [die]
    ]

    set number_friends (count friend-neighbors)
  ]
  ask friends [
    hide-link
    ;set color 86
  ]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;                    Procedures to run the model                                  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to go
  if ticks >= stop_time [ stop ]
  file-open (word "model_output/run_" behaviorspace-run-number ".csv")          ; open the file to safe the results

  go-fishing

  file-close                                ; close the before open file
  tick
end



; main procedure to chose a  fishing location and catch fish there; activated in go
to go-fishing
  ask angler [
    ifelse draw-path? [ pen-down ] [ pen-up ]                                  ; make a line between homelocation and fishing location
    set current_angler who

    set random_angler_nr (random-float 1)
    if (random_angler_nr < (9 / 365))[                                         ; set the probability to go on a fishng trip that on average 9 trips are taken per year

      let random_nr (random-float 1)                                             ; random number that decide if a random location is explored or a specific location is chosen
      if (random_nr < parameter_e) [                                           ; if random number < parameter e than a random location is explored
        explore-location                                                       ; procedure to select a random location (see below)
      ]
      if (random_nr >= parameter_e) [                                          ; if random number > parameter e than a specific location is chosen
        let own_catch daily_angler_catch                                       ; this block determines the own last catch and the best last catch of friends
        ifelse (own_catch < friends-catch)                                     ; procedure to decide if to go to own location or best of friends (best friends catch is reported below)
        [friends-location]
        [choose-location]
      ]

      set total_angler_trips (total_angler_trips + 1)                          ; count the trips of one angler
      set total_trips (total_trips + 1)                                        ; count the trips of all anglers
    ]
  ]
  ask angler [

    if (random_angler_nr < (9 / 365))[                                         ; set the probability to go on a fishng trip that on average 9 trips are taken per year

      get-catch                                                                ; procedure see below

      set total_angler_catch (daily_angler_catch + total_angler_catch)         ; count the catch of one angler
      set total_catch (total_catch + daily_angler_catch)                       ; count the catch of all anglers
    ]
  ]
end





; procedure to explore a random fishing location, activated in go-fishing
to explore-location
  let method fishing_method                                                                                     ; safe the fishing method of the current agent as variable
  let possible_locations locations with [location_method = method]                                              ; only allow locations where the fishing method of the agent is possible

  set chosen_location one-of possible_locations                                                                 ; angler chose the location of the possible locations (same fishing method) with the probability of each location being picked is proportional to the utility

  ; for model output analysis
  ask chosen_location [                                                                                         ; to calculate visited locations and distribution of angler between the locations
    set visited true
    set total_visits (total_visits + 1)
    set current_location who
  ]
  set total_traveled_dist (total_traveled_dist + [distances] of connection current_location current_angler)     ; to calculate the mean travel distances

  ; to visually move the agent
  move-to chosen_location                                                                                       ; agent move to the location and draw line if draw-path on
  setxy homelocation_x homelocation_y                                                                           ; set the agent location back to the homelocation
end



; reporter to calculate the maximum friends catch
to-report friends-catch
  let friends_catch 0

  if (count my-out-friends > 0) [                                        ; only if there are at least one friends. my-out-friends is a list of links
    let all_friends friend-neighbors                                     ; agentset of all angler that have a friend connection. firend-neighbors is a list of angler that are friends
    let best_friend max-one-of all_friends [daily_angler_catch]          ; angler with the highest catch is determindes
    set friends_catch [daily_angler_catch] of best_friend                ; the highest catch is saved as variable
  ]
  report friends_catch
end


; procedure to select the best fishing location of friends, activated in go-fishing
to friends-location
  let all_friends friend-neighbors                                     ; agentset of all angler that have a friend connection. firend-neighbors is a list of angler that are friends
  let best_friend max-one-of all_friends [daily_angler_catch]          ; angler with the highest catch is determinded.
  set chosen_location [chosen_location] of best_friend                 ; the last location of the best friend is set as new chosen location

  ask chosen_location [
    set visited true
    set total_visits (total_visits + 1)
    set current_location who
  ]
  set total_traveled_dist (total_traveled_dist + [distances] of connection current_location current_angler)

  move-to chosen_location                                                           ; agent move to the location and draw line if draw-path on
  setxy homelocation_x homelocation_y                                               ; set the agent location back to the homelocation
end




; procedure to choose a fishing location, activated in go-fishing
to choose-location
  let method fishing_method                                                                                     ; safe the fishing method of the current agent as variable
  let possible_locations locations with [location_method = method]                                              ; only allow locations where the fishing method of the agent is possible

  set chosen_location rnd:weighted-one-of possible_locations [location_utility]                                 ; angler chose the location of the possible locations (same fishing method) with the probability of each location being picked is proportional to the utility (which is calculated in the reporter location_utility).

  ; for model output analysis
  ask chosen_location [                                                                                         ; to calculate visited locations and distribution of angler between the locations
    set visited true
    set total_visits (total_visits + 1)
    set current_location who
  ]
  set total_traveled_dist (total_traveled_dist + [distances] of connection current_location current_angler)     ; to calculate the mean travel distances

  ; to visually move the agent

  move-to chosen_location                                                                                       ; agent move to the location and draw line if draw-path on
  setxy homelocation_x homelocation_y                                                                           ; set the agent location back to the homelocation
end


; reporter to caluclate the utility of each possible location
to-report location_utility
  set current_location who

  let catch_utility CPUE_mean * catch_utility_b                                 ; mulitplies the average catch of a location (CPUE_mean) with the linear factor of the catch utility function

  let dist [distances] of connection current_location current_angler            ; safe the distance of the link (connection) between the currently active angler of the go-fishing function and the current location for which the utility is calculated
  let dist_utility 1 - dist * dist_utility_b                                    ; mulitplies the distance (dist) between fishing location and homelocation of the angler with the linear factor of the distance utility function

  report parameter_a * catch_utility + (1 - parameter_a) * dist_utility         ; combine the distance- and catch utility over the weighting paramete a
end





; procedure to give the angler a catch, activated in go-fishing
to get-catch
  let cmean [CPUE_mean] of chosen_location                                      ; get the CPUE_mean of the chosen location
  let csd [CPUE_sd] of chosen_location                                          ; get the CPUE_sd of the chosen location
  set daily_angler_catch (round (random-normal cmean csd))                      ; draw the daily catch of a normal distribution with parameters of the choosen location

  if (daily_angler_catch < 0) [
    set daily_angler_catch 0
  ]

  let catch daily_angler_catch
  ask chosen_location [
    set total_location_catch (total_location_catch + catch)
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
199
36
1324
1162
-1
-1
27.244
1
10
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
20
36
98
90
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
104
36
182
91
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
1490
38
1594
83
# charter angler
count angler with [fishing_method = \"Kutter\"]
17
1
11

MONITOR
1490
88
1594
133
# boat angler
count angler with [fishing_method = \"Boot\"]
17
1
11

MONITOR
1490
137
1593
182
# shore angler
count angler with [fishing_method = \"Land\"]
17
1
11

PLOT
1357
220
1571
384
total fishing trips
time
number trips
0.0
365.0
0.0
10.0
true
false
"" ""
PENS
"number_trips" 1.0 0 -16777216 true "" "plot total_trips"

MONITOR
1575
220
1744
265
mean number of trips per angler
total_trips / number_angler
17
1
11

SWITCH
20
110
183
143
draw-path?
draw-path?
1
1
-1000

MONITOR
1577
402
1654
447
mean CPUE
precision (total_catch / total_trips) 3
17
1
11

PLOT
1357
401
1572
566
total catch
time
number catch
0.0
365.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot total_catch"

MONITOR
1355
38
1474
83
# charter harbours
count locations with [location_method = \"Kutter\"]
17
1
11

MONITOR
1355
87
1474
132
# boat ramps
count locations with [location_method = \"Boot\"]
17
1
11

MONITOR
1355
136
1474
181
# shore locations
count locations with [location_method = \"Land\"]
17
1
11

MONITOR
1630
40
1730
85
min of zipcodes
min [homelocation_name] of angler
17
1
11

MONITOR
1630
95
1732
140
max of zipcodes
max [homelocation_name] of angler
17
1
11

SLIDER
10
160
187
193
value-of-parameter_a
value-of-parameter_a
0
1
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
5
360
182
393
value-of-parameter_e
value-of-parameter_e
0
1
0.5
0.05
1
NIL
HORIZONTAL

INPUTBOX
20
210
172
270
value-of-catch_utility_b
0.25
1
0
Number

INPUTBOX
20
280
172
340
value-of-dist_utility_b
0.00195
1
0
Number

MONITOR
1360
615
1502
660
mean number of friends
mean [number_friends] of angler
1
1
11

MONITOR
1515
615
1647
660
min number_friends
min [number_friends] of angler
1
1
11

MONITOR
1670
615
1792
660
max number_friends
max [number_friends] of angler
1
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <steppedValueSet variable="value-of-parameter_a" first="0" step="0.05" last="1"/>
    <steppedValueSet variable="value-of-parameter_b" first="0" step="0.05" last="1"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@