using { /Verse.org/SceneGraph }
using { /Verse.org/Simulation }
using { /Verse.org/Assets }
using { /Fortnite.com/Playspaces }

catchable_ui_state := enum:
    Active
    Held
    Deactive

catchable_widget_component := class<final_super>(component):

    @editable
    ActiveCrosshair<public>:texture

    @editable
    HeldCrosshair<public>:texture

    @editable
    DeactiveCrosshair<public>:texture

    var<private> WidgetPerPlayer<public>:[player]catchable_widget = map{}
    var SubscribeObjects:?tuple(cancelable, cancelable) = false

    OnSimulate<override>():void=
        if:
            FortPlayspace := Entity.GetPlayspaceForEntity[]
        then:
            for:
                PlayerElement : FortPlayspace.GetPlayers()
            do:
                OnPlay(PlayerElement)
            Cancelables := 
                (
                    FortPlayspace.PlayerAddedEvent().Subscribe(OnPlay),
                    FortPlayspace.PlayerRemovedEvent().Subscribe(OnLeave)
                )
            set SubscribeObjects = option{Cancelables}

    OnEndSimulation<override>():void=
        if(Cancelable := SubscribeObjects?):
            Cancelable(0).Cancel()
            Cancelable(1).Cancel()
            set SubscribeObjects = false

        if:
            FortPlayspace := Entity.GetPlayspaceForEntity[]
        then:
            for:
                PlayerElement : FortPlayspace.GetPlayers()
            do:
                OnLeave(PlayerElement)

    UpdateCrossHair<public>(InPlayer:player, InState:catchable_ui_state):void=
        if(CurrentWidget := WidgetPerPlayer[InPlayer]):
            case(InState):
                catchable_ui_state.Active=>
                    CurrentWidget.UpdateCrossHair(ActiveCrosshair)
                catchable_ui_state.Held=>
                    CurrentWidget.UpdateCrossHair(HeldCrosshair)
                catchable_ui_state.Deactive=>
                    CurrentWidget.UpdateCrossHair(DeactiveCrosshair)

    OnPlay<private>(InPlayer:player):void=
        NewWidget := MakeCatchableWidget(InPlayer, DeactiveCrosshair)
        NewWidget.AddGameplayUI()
        if:
            set WidgetPerPlayer[InPlayer] = NewWidget

    OnLeave<private>(InPlayer:player):void=
        if(CurrentWidget := WidgetPerPlayer[InPlayer]):
            CurrentWidget.RemoveUI()
            set WidgetPerPlayer = WidgetPerPlayer.RemoveKey(InPlayer)