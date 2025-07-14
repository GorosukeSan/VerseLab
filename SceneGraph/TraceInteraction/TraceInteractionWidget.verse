using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Assets }
using { /Verse.org/Simulation }
using { /Verse.org/SceneGraph }

MakeTraceInteractionWidget<public><constructor>(InPlayer:player, InDefaultImage:texture)<transacts> := trace_interaction_widget:
    Player := InPlayer
    CrossHair := texture_block:
        DefaultImage := InDefaultImage
        DefaultDesiredSize := vector2{X := 64.0, Y := 64.0}

trace_interaction_widget<public> := class<final>:

    Player<public>:player
    CrossHair<public>:texture_block

    var<private> MaybeCurrentCanvas<public>:?canvas = false

    UpdateCrossHair<public>(InImage:texture):void=
        CrossHair.SetImage(InImage)

    AddGameplayUI<public>():void=
        if:
            PlayerUI := GetPlayerUI[Player]
        then:
            NewCanvas := CreateCanvas()
            PlayerUI.AddWidget(NewCanvas)
            set MaybeCurrentCanvas = option{NewCanvas}

    RemoveUI<public>():void=
        if:
            PlayerUI := GetPlayerUI[Player]
            CurrentCanvas := MaybeCurrentCanvas?
        then:
            PlayerUI.RemoveWidget(CurrentCanvas)
            set MaybeCurrentCanvas = false

    CreateCanvas<private>():canvas=
        canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors:
                        Minimum := vector2{X := 0.5, Y := 0.5}
                        Maximum := vector2{X := 0.5, Y := 0.5}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    SizeToContent := true
                    Widget := CrossHair