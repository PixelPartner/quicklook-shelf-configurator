module Scene3d exposing
    ( render, toEntities
    , Lights, oneLight, twoLights, threeLights, fourLights
    , Option, antialias, clearColor, devicePixelRatio, gammaCorrection
    )

{-|

@docs render, toEntities

@docs Lights, oneLight, twoLights, threeLights, fourLights, fiveLights, sixLights, sevenLights, eightLights

@docs Option, antialias, clearColor, devicePixelRatio, gammaCorrection

-}

import Camera3d exposing (Camera3d)
import Color exposing (Color)
import Geometry.Interop.LinearAlgebra.Frame3d as Frame3d
import Geometry.Interop.LinearAlgebra.Point3d as Point3d
import Html exposing (Html)
import Html.Attributes
import Luminance
import Math.Matrix4 exposing (Mat4)
import Math.Vector3 as Vector3 exposing (Vec3)
import Math.Vector4 exposing (Vec4)
import Pixels exposing (Pixels, inPixels)
import Point3d exposing (Point3d)
import Quantity exposing (Quantity)
import Rectangle2d
import Scene3d.Chromaticity as Chromaticity exposing (Chromaticity)
import Scene3d.Drawable exposing (Drawable)
import Scene3d.Exposure as Exposure exposing (Exposure)
import Scene3d.Light exposing (Light)
import Scene3d.Transformation as Transformation exposing (Transformation)
import Scene3d.Types as Types exposing (DrawFunction, LightMatrices, Node(..))
import Viewpoint3d
import WebGL
import WebGL.Settings
import WebGL.Settings.DepthTest as DepthTest
import WebGL.Settings.StencilTest as StencilTest
import WebGL.Texture exposing (Texture)



----- LIGHTS -----
--
-- type:
--   0 : disabled
--   1 : directional (XYZ is direction to light, i.e. reversed light direction)
--   2 : point (XYZ is light position)
--
-- radius is unused for now (will hopefully add sphere lights in the future)
--
-- [ x_i     r_i       x_j     r_j      ]
-- [ y_i     g_i       y_j     g_j      ]
-- [ z_i     b_i       z_j     b_j      ]
-- [ type_i  radius_i  type_j  radius_j ]


type Lights units coordinates
    = SingleUnshadowedPass LightMatrices
    | SingleShadowedPass LightMatrices
    | TwoPasses LightMatrices LightMatrices


disabledLight : Light units coordinates
disabledLight =
    Types.Light
        { type_ = 0
        , x = 0
        , y = 0
        , z = 0
        , r = 0
        , g = 0
        , b = 0
        , radius = 0
        }


lightPair : Light units coordinates -> Light units coordinates -> Mat4
lightPair (Types.Light first) (Types.Light second) =
    Math.Matrix4.fromRecord
        { m11 = first.x
        , m21 = first.y
        , m31 = first.z
        , m41 = first.type_
        , m12 = first.r
        , m22 = first.g
        , m32 = first.b
        , m42 = first.radius
        , m13 = second.x
        , m23 = second.y
        , m33 = second.z
        , m43 = second.type_
        , m14 = second.r
        , m24 = second.g
        , m34 = second.b
        , m44 = second.radius
        }


lightingDisabled : LightMatrices
lightingDisabled =
    { lights12 = lightPair disabledLight disabledLight
    , lights34 = lightPair disabledLight disabledLight
    , lights56 = lightPair disabledLight disabledLight
    , lights78 = lightPair disabledLight disabledLight
    }


noLights : Lights units coordinates
noLights =
    SingleUnshadowedPass lightingDisabled


oneLight : Light units coordinates -> { castsShadows : Bool } -> Lights units coordinates
oneLight light { castsShadows } =
    let
        lightMatrices =
            { lights12 = lightPair light disabledLight
            , lights34 = lightPair disabledLight disabledLight
            , lights56 = lightPair disabledLight disabledLight
            , lights78 = lightPair disabledLight disabledLight
            }
    in
    if castsShadows then
        SingleShadowedPass lightMatrices

    else
        SingleUnshadowedPass lightMatrices


twoLights :
    ( Light units coordinates, { castsShadows : Bool } )
    -> Light units coordinates
    -> Lights units coordinates
twoLights first second =
    eightLights
        first
        second
        disabledLight
        disabledLight
        disabledLight
        disabledLight
        disabledLight
        disabledLight


threeLights :
    ( Light units coordinates, { castsShadows : Bool } )
    -> Light units coordinates
    -> Light units coordinates
    -> Lights units coordinates
threeLights first second third =
    eightLights
        first
        second
        third
        disabledLight
        disabledLight
        disabledLight
        disabledLight
        disabledLight


fourLights :
    ( Light units coordinates, { castsShadows : Bool } )
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Lights units coordinates
fourLights first second third fourth =
    eightLights
        first
        second
        third
        fourth
        disabledLight
        disabledLight
        disabledLight
        disabledLight


fiveLights :
    ( Light units coordinates, { castsShadows : Bool } )
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Lights units coordinates
fiveLights first second third fourth fifth =
    eightLights
        first
        second
        third
        fourth
        fifth
        disabledLight
        disabledLight
        disabledLight


sixLights :
    ( Light units coordinates, { castsShadows : Bool } )
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Lights units coordinates
sixLights first second third fourth fifth sixth =
    eightLights
        first
        second
        third
        fourth
        fifth
        sixth
        disabledLight
        disabledLight


sevenLights :
    ( Light units coordinates, { castsShadows : Bool } )
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Lights units coordinates
sevenLights first second third fourth fifth sixth seventh =
    eightLights
        first
        second
        third
        fourth
        fifth
        sixth
        seventh
        disabledLight


eightLights :
    ( Light units coordinates, { castsShadows : Bool } )
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Light units coordinates
    -> Lights units coordinates
eightLights ( firstLight, { castsShadows } ) secondLight thirdLight fourthLight fifthLight sixthLight seventhLight eigthLight =
    if castsShadows then
        TwoPasses
            { lights12 = lightPair firstLight secondLight
            , lights34 = lightPair thirdLight fourthLight
            , lights56 = lightPair fifthLight sixthLight
            , lights78 = lightPair seventhLight eigthLight
            }
            { lights12 = lightPair secondLight thirdLight
            , lights34 = lightPair fourthLight fifthLight
            , lights56 = lightPair sixthLight seventhLight
            , lights78 = lightPair eigthLight disabledLight
            }

    else
        SingleUnshadowedPass
            { lights12 = lightPair firstLight secondLight
            , lights34 = lightPair thirdLight fourthLight
            , lights56 = lightPair fifthLight sixthLight
            , lights78 = lightPair seventhLight eigthLight
            }



----- RENDERING -----


type alias RenderPass =
    LightMatrices -> List WebGL.Settings.Setting -> WebGL.Entity


type alias RenderPasses =
    { meshes : List RenderPass
    , shadows : List RenderPass
    }


createRenderPass : Mat4 -> Mat4 -> Transformation -> DrawFunction -> RenderPass
createRenderPass sceneProperties viewMatrix transformation drawFunction =
    drawFunction
        sceneProperties
        transformation.scale
        (Transformation.modelMatrix transformation)
        transformation.isRightHanded
        viewMatrix


collectRenderPasses : Mat4 -> Mat4 -> Transformation -> Node -> RenderPasses -> RenderPasses
collectRenderPasses sceneProperties viewMatrix currentTransformation node accumulated =
    case node of
        EmptyNode ->
            accumulated

        Transformed transformation childNode ->
            collectRenderPasses
                sceneProperties
                viewMatrix
                (Transformation.compose transformation currentTransformation)
                childNode
                accumulated

        MeshNode meshDrawFunction maybeShadowDrawFunction ->
            let
                updatedMeshes =
                    createRenderPass
                        sceneProperties
                        viewMatrix
                        currentTransformation
                        meshDrawFunction
                        :: accumulated.meshes

                updatedShadows =
                    case maybeShadowDrawFunction of
                        Nothing ->
                            accumulated.shadows

                        Just shadowDrawFunction ->
                            createRenderPass
                                sceneProperties
                                viewMatrix
                                currentTransformation
                                shadowDrawFunction
                                :: accumulated.shadows
            in
            { meshes = updatedMeshes
            , shadows = updatedShadows
            }

        Group childNodes ->
            List.foldl
                (collectRenderPasses
                    sceneProperties
                    viewMatrix
                    currentTransformation
                )
                accumulated
                childNodes



-- ## Overall scene Properties
--
-- projectionType:
--   0: perspective (camera XYZ is eye position)
--   1: orthographic (camera XYZ is direction to screen)
--
-- [ clipDistance  cameraX         whiteR  * ]
-- [ aspectRatio   cameraY         whiteG  * ]
-- [ kc            cameraZ         whiteB  * ]
-- [ kz            projectionType  gamma   * ]


depthTestDefault : List WebGL.Settings.Setting
depthTestDefault =
    [ DepthTest.default ]


outsideStencil : List WebGL.Settings.Setting
outsideStencil =
    [ DepthTest.lessOrEqual { write = True, near = 0, far = 1 }
    , StencilTest.test
        { ref = 0
        , mask = 0xFF
        , test = StencilTest.equal
        , fail = StencilTest.keep
        , zfail = StencilTest.keep
        , zpass = StencilTest.keep
        , writeMask = 0x00
        }
    ]


insideStencil : List WebGL.Settings.Setting
insideStencil =
    [ DepthTest.lessOrEqual { write = True, near = 0, far = 1 }
    , StencilTest.test
        { ref = 0
        , mask = 0xFF
        , test = StencilTest.notEqual
        , fail = StencilTest.keep
        , zfail = StencilTest.keep
        , zpass = StencilTest.keep
        , writeMask = 0x00
        }
    ]


createShadowStencil : List WebGL.Settings.Setting
createShadowStencil =
    [ DepthTest.less { write = False, near = 0, far = 1 }
    , WebGL.Settings.colorMask False False False False
    , StencilTest.testSeparate
        { ref = 1
        , mask = 0xFF
        , writeMask = 0xFF
        }
        { test = StencilTest.always
        , fail = StencilTest.keep
        , zfail = StencilTest.keep
        , zpass = StencilTest.incrementWrap
        }
        { test = StencilTest.always
        , fail = StencilTest.keep
        , zfail = StencilTest.keep
        , zpass = StencilTest.decrementWrap
        }
    ]


call : List RenderPass -> LightMatrices -> List WebGL.Settings.Setting -> List WebGL.Entity
call renderPasses lightMatrices settings =
    renderPasses
        |> List.map (\renderPass -> renderPass lightMatrices settings)


toEntities :
    { options : List Option
    , lights : Lights units coordinates
    , scene : Drawable units coordinates
    , camera : Camera3d units coordinates
    , exposure : Exposure
    , whiteBalance : Chromaticity
    , screenWidth : Quantity Float Pixels
    , screenHeight : Quantity Float Pixels
    }
    -> List WebGL.Entity
toEntities { options, lights, scene, camera, exposure, whiteBalance, screenWidth, screenHeight } =
    let
        givenGammaCorrection =
            getGammaCorrection options

        aspectRatio =
            Quantity.ratio screenWidth screenHeight

        projectionParameters =
            Camera3d.projectionParameters { screenAspectRatio = aspectRatio }
                camera

        clipDistance =
            Math.Vector4.getX projectionParameters

        kc =
            Math.Vector4.getZ projectionParameters

        kz =
            Math.Vector4.getW projectionParameters

        eyePoint =
            Camera3d.viewpoint camera
                |> Viewpoint3d.eyePoint
                |> Point3d.unwrap

        projectionType =
            if kz == 0 then
                0

            else
                1

        ( r, g, b ) =
            Chromaticity.toLinearRgb whiteBalance

        maxLuminance =
            Luminance.inNits (Exposure.maxLuminance exposure)

        sceneProperties =
            Math.Matrix4.fromRecord
                { m11 = clipDistance
                , m21 = aspectRatio
                , m31 = kc
                , m41 = kz
                , m12 = eyePoint.x
                , m22 = eyePoint.y
                , m32 = eyePoint.z
                , m42 = projectionType
                , m13 = maxLuminance * r
                , m23 = maxLuminance * g
                , m33 = maxLuminance * b
                , m43 = givenGammaCorrection
                , m14 = 0
                , m24 = 0
                , m34 = 0
                , m44 = 0
                }

        viewMatrix =
            Camera3d.viewMatrix camera

        (Types.Drawable rootNode) =
            scene

        renderPasses =
            collectRenderPasses
                sceneProperties
                viewMatrix
                Transformation.identity
                rootNode
                { meshes = []
                , shadows = []
                }
    in
    case lights of
        SingleUnshadowedPass lightMatrices ->
            call renderPasses.meshes lightMatrices depthTestDefault

        SingleShadowedPass lightMatrices ->
            List.concat
                [ call renderPasses.meshes lightingDisabled depthTestDefault
                , call renderPasses.shadows lightMatrices createShadowStencil
                , call renderPasses.meshes lightMatrices outsideStencil
                ]

        TwoPasses allLightMatrices unshadowedLightMatrices ->
            List.concat
                [ call renderPasses.meshes allLightMatrices depthTestDefault
                , call renderPasses.shadows allLightMatrices createShadowStencil
                , call renderPasses.meshes unshadowedLightMatrices insideStencil
                ]


render :
    { options : List Option
    , lights : Lights units coordinates
    , scene : Drawable units coordinates
    , camera : Camera3d units coordinates
    , exposure : Exposure
    , whiteBalance : Chromaticity
    , screenWidth : Quantity Float Pixels
    , screenHeight : Quantity Float Pixels
    }
    -> Html msg
render arguments =
    let
        widthInPixels =
            inPixels arguments.screenWidth

        heightInPixels =
            inPixels arguments.screenHeight

        givenDevicePixelRatio =
            getDevicePixelRatio arguments.options

        givenAntialias =
            getAntialias arguments.options

        givenClearColor =
            Color.toRgba (getClearColor arguments.options)

        commonOptions =
            [ WebGL.depth 1
            , WebGL.stencil 0
            , WebGL.clearColor
                givenClearColor.red
                givenClearColor.green
                givenClearColor.blue
                givenClearColor.alpha
            ]

        webGLOptions =
            if givenAntialias then
                WebGL.antialias :: commonOptions

            else
                commonOptions
    in
    WebGL.toHtmlWith webGLOptions
        [ Html.Attributes.width (round (givenDevicePixelRatio * widthInPixels))
        , Html.Attributes.height (round (givenDevicePixelRatio * heightInPixels))
        , Html.Attributes.style "width" (String.fromFloat widthInPixels ++ "px")
        , Html.Attributes.style "height" (String.fromFloat heightInPixels ++ "px")
        ]
        (toEntities arguments)



----- OPTIONS -----


type Option
    = DevicePixelRatio Float
    | GammaCorrection Float
    | Antialias Bool
    | Alpha Bool
    | ClearColor Color


devicePixelRatio : Float -> Option
devicePixelRatio value =
    DevicePixelRatio value


gammaCorrection : Float -> Option
gammaCorrection value =
    GammaCorrection value


antialias : Bool -> Option
antialias value =
    Antialias value


clearColor : Color -> Option
clearColor color =
    ClearColor color


getDevicePixelRatio : List Option -> Float
getDevicePixelRatio options =
    let
        defaultValue =
            1.0

        update option oldValue =
            case option of
                DevicePixelRatio newValue ->
                    newValue

                _ ->
                    oldValue
    in
    List.foldl update defaultValue options


getGammaCorrection : List Option -> Float
getGammaCorrection options =
    let
        defaultValue =
            1 / 2.2

        update option oldValue =
            case option of
                GammaCorrection newValue ->
                    newValue

                _ ->
                    oldValue
    in
    List.foldl update defaultValue options


getAntialias : List Option -> Bool
getAntialias options =
    let
        defaultValue =
            True

        update option oldValue =
            case option of
                Antialias newValue ->
                    newValue

                _ ->
                    oldValue
    in
    List.foldl update defaultValue options


getAlpha : List Option -> Bool
getAlpha options =
    let
        defaultValue =
            True

        update option oldValue =
            case option of
                Alpha newValue ->
                    newValue

                _ ->
                    oldValue
    in
    List.foldl update defaultValue options


getClearColor : List Option -> Color
getClearColor options =
    let
        defaultValue =
            Color.rgba 1.0 1.0 1.0 0.0

        update option oldValue =
            case option of
                ClearColor newValue ->
                    newValue

                _ ->
                    oldValue
    in
    List.foldl update defaultValue options