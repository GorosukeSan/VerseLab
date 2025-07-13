using { /Verse.org/Simulation }
using { /Verse.org/SceneGraph }
using { /Verse.org/Assets }
using { /UnrealEngine.com/Temporary/UI }

using { /UnrealEngine.com/Temporary/SpatialMath }

MakeCatchableWidget<public><constructor>(InPlayer:player, InDefaultImage:texture)<transacts> := catchable_widget:
    Player := InPlayer
    CrossHair := texture_block:
        DefaultImage := InDefaultImage
        DefaultDesiredSize := vector2{X := 64.0, Y := 64.0}

catchable_widget<public> := class:

    Player<public>:player
    CrossHair<public>:texture_block

    var MaybeCurrentCanvas:?canvas = false

    AddGameplayUI<public>():void=
        if(PlayerUI := GetPlayerUI[Player]):
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

    UpdateCrossHair<public>(InTexture:texture):void=
        CrossHair.SetImage(InTexture)

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