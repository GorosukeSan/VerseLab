using { /Verse.org/SceneGraph }
using { /Verse.org/Simulation }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/Characters }
using { /Verse.org/SpatialMath }
using { /UnrealEngine.com/Temporary }
using { /Fortnite.com/Devices }

catchable_event := class(scene_event):
    IsCatched:logic
    Instigator:player
    CatchDistance:float
    RayTraceInfo:ray_trace_info

ray_trace_info := struct:
    ViewRotation:rotation
    ViewLocation:transform
    ForwardLocation:vector3

(InCharacter:fort_character).GetRayTraceInfo(InForwardDistance:float)<transacts>:ray_trace_info=
    ViewRotation := InCharacter.GetViewRotation()
    ViewLocation := InCharacter.GetViewLocation()
    SceneViewRotation := SpatialMath.FromRotation(ViewRotation)
    SceneViewLocation := transform:
        Translation := SpatialMath.FromVector3(ViewLocation)
    ForwardLocation := SceneViewRotation.GetForwardAxis() * InForwardDistance
    ray_trace_info:
        ViewRotation := SceneViewRotation
        ViewLocation := SceneViewLocation
        ForwardLocation := ForwardLocation

catchable_manager_component<public> := class<final_super>(component):

    @editable
    RayDistance:float = 1000.0

    @editable
    CatchInput:input_trigger_device = input_trigger_device{}

    @editable
    PullInput:input_trigger_device = input_trigger_device{}

    @editable
    PushInput:input_trigger_device = input_trigger_device{}

    @editable
    PushPullSpeed:float = 50.0

    var HoldObjectPlayers:[player]tuple(entity, float) = map{}
    var IsHeldOnceForPlayer:[]player = array{}
    var MaybeCatchableWidgetComponent:?catchable_widget_component = false

    OnBeginSimulation<override>():void=
        TickEvents.PrePhysics.Subscribe(OnUpdate)
        PullInput.PressedEvent.Subscribe(OnInputPull)
        PushInput.PressedEvent.Subscribe(OnInputPush)

        if(TargetComponent := Entity.GetComponent[catchable_widget_component]):
            set MaybeCatchableWidgetComponent = option{TargetComponent}

    OnUpdate(DeltaTime:float):void=
        defer:
            for:
                PlayerElement -> CurrentHitEntity : HoldObjectPlayers
                PlayerCharacter := PlayerElement.GetFortCharacter[]
                CurrentHoldObject := HoldObjectPlayers[PlayerElement]
            do:
                RayTraceInfo := PlayerCharacter.GetRayTraceInfo(RayDistance)
                var TraceSuccess:logic = false
                for:
                    SweepHit : Entity.FindSweepHits(RayTraceInfo.ForwardLocation, RayTraceInfo.ViewLocation, collision_sphere{Radius := 10.0})
                    HitEntity := SweepHit.TargetComponent.Entity
                    NewCatchableObject := HitEntity.GetComponent[catchable_object_component]
                    HitEntity = CurrentHitEntity(0)
                do:
                    set TraceSuccess = true
                if(not TraceSuccess? or not CatchInput.IsHeld[PlayerElement]):
                    set HoldObjectPlayers = HoldObjectPlayers.RemoveKey(PlayerElement)
                    NewCatchableEvent := catchable_event:
                        IsCatched := false
                        Instigator := PlayerElement
                        RayTraceInfo := RayTraceInfo
                        CatchDistance := Distance(CurrentHitEntity(0).GetGlobalTransform().Translation, RayTraceInfo.ViewLocation.Translation)
                    CurrentHitEntity(0).SendDirect(NewCatchableEvent)

        if:
            FortPlayspace := Entity.GetPlayspaceForEntity[]
        then:
            var CatchablePlayrs:[]player = array{}
            for:
                PlayerElement : FortPlayspace.GetPlayers()
                PlayerCharacter := PlayerElement.GetFortCharacter[]
            do:
                RayTraceInfo := PlayerCharacter.GetRayTraceInfo(RayDistance)
                for:
                    SweepHit : Entity.FindSweepHits(RayTraceInfo.ForwardLocation, RayTraceInfo.ViewLocation, collision_sphere{Radius := 10.0})
                    HitEntity := SweepHit.TargetComponent.Entity
                    CatchableObject := HitEntity.GetComponent[catchable_object_component]
                    #(not CatchableObject.Owner? or CatchableObject.Owner? = PlayerElement)
                do:
                    set CatchablePlayrs += array{PlayerElement}
                    CurrentDistance := 
                        if(PlayerInfo := HoldObjectPlayers[PlayerElement]):
                            PlayerInfo(1)
                        else:
                            Distance(HitEntity.GetGlobalTransform().Translation, RayTraceInfo.ViewLocation.Translation)
                    if:
                        CatchInput.IsHeld[PlayerElement]
                        set HoldObjectPlayers[PlayerElement] = (HitEntity, CurrentDistance)
                    then:
                        NewCatchableEvent := catchable_event:
                            IsCatched := true
                            Instigator := PlayerElement
                            RayTraceInfo := RayTraceInfo
                            CatchDistance := CurrentDistance
                        HitEntity.SendDirect(NewCatchableEvent)
            if:
                CatchableWidgetComponent := MaybeCatchableWidgetComponent?
            then:
                for:
                    PlayerElement : FortPlayspace.GetPlayers()
                do:
                    if(CatchablePlayrs.Find[PlayerElement]):
                        if(CatchInput.IsHeld[PlayerElement]):
                            CatchableWidgetComponent.UpdateCrossHair(PlayerElement, catchable_ui_state.Held)
                        else:
                            CatchableWidgetComponent.UpdateCrossHair(PlayerElement, catchable_ui_state.Active)
                    else:
                        CatchableWidgetComponent.UpdateCrossHair(PlayerElement, catchable_ui_state.Deactive)

    OnInputPull(Agent:agent):void=
        if:
            Player := player[Agent]
            CurrentHeld := HoldObjectPlayers[Player]
            set HoldObjectPlayers[Player] = (CurrentHeld(0), CurrentHeld(1) + PushPullSpeed)
        then:

    OnInputPush(Agent:agent):void=
        if:
            Player := player[Agent]
            CurrentHeld := HoldObjectPlayers[Player]
            set HoldObjectPlayers[Player] = (CurrentHeld(0), CurrentHeld(1) - PushPullSpeed)
        then:

catchable_object_component<public> := class<final_super>(component):

    var<private> Owner:?player = false
    var<private> IsFalling:logic = false
    FallSpeed:float = 50.0

    OnBeginSimulation<override>():void=
        TickEvents.PrePhysics.Subscribe(OnUpdate)

    OnReceive<override>(SceneEvent:scene_event):logic=
        if(CatchableEvent := catchable_event[SceneEvent]):
            if(CatchableEvent.IsCatched?):
                set Owner = option{CatchableEvent.Instigator}
                CurrentTransform := Entity.GetGlobalTransform()
                var NewTransform:transform = transform:
                    Translation := CatchableEvent.RayTraceInfo.ViewLocation.Translation + CatchableEvent.RayTraceInfo.ViewRotation.GetForwardAxis() * CatchableEvent.CatchDistance
                    Rotation := Entity.GetGlobalTransform().Rotation
                for:
                    OverlapHit : Entity.FindOverlapHits(NewTransform)
                do:
                    set NewTransform = CurrentTransform
                Entity.SetGlobalTransform(NewTransform)
            else:
                set Owner = false
        false

    OnUpdate(DeltaTime:float):void=
        if(not Owner?):
            CurrentTransform := Entity.GetGlobalTransform()
            if(IsFalling?):
                NewTransform := transform:
                    Translation := CurrentTransform.Translation + vector3{Up := -FallSpeed * DeltaTime}
                    Rotation := CurrentTransform.Rotation
                for:
                    OverlapHit : Entity.FindOverlapHits()
                do:
                    set IsFalling = false
                Entity.SetGlobalTransform(NewTransform)
            else:
                var IsCollide:logic = false
                for:
                    SweepHit : Entity.FindOverlapHits()
                do:
                    set IsCollide = true
                if(not IsCollide?):
                    set IsFalling = true