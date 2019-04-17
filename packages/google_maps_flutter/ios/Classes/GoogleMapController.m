// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "GoogleMapController.h"

#pragma mark - Conversion of JSON-like values sent via platform channels. Forward declarations.

static id positionToJson(GMSCameraPosition* position);
static double toDouble(id json);
static CLLocationCoordinate2D toLocation(id json);
static GMSPath* toPath(id json);
static UIColor* toUIColor(id json);
static GMSCameraPosition* toOptionalCameraPosition(id json);
static GMSCoordinateBounds* toOptionalBounds(id json);
static GMSCameraUpdate* toCameraUpdate(id json);
static void interpretMapOptions(id json, id<FLTGoogleMapOptionsSink> sink);
static void interpretMarkerOptions(id json, id<FLTGoogleMapMarkerOptionsSink> sink,
                                   NSObject<FlutterPluginRegistrar>* registrar);
static void interpretPolygonOptions(id json, id<FLTGoogleMapPolygonOptionsSink> sink,
                                   NSObject<FlutterPluginRegistrar>* registrar);

@implementation FLTGoogleMapFactory {
  NSObject<FlutterPluginRegistrar>* _registrar;
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  self = [super init];
  if (self) {
    _registrar = registrar;
  }
  return self;
}

- (NSObject<FlutterMessageCodec>*)createArgsCodec {
  return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args {
  return [[FLTGoogleMapController alloc] initWithFrame:frame
                                        viewIdentifier:viewId
                                             arguments:args
                                             registrar:_registrar];
}
@end

@implementation FLTGoogleMapController {
  GMSMapView* _mapView;
  int64_t _viewId;
  NSMutableDictionary* _markers;
  NSMutableDictionary* _polygons;
  FlutterMethodChannel* _channel;
  BOOL _trackCameraPosition;
  NSObject<FlutterPluginRegistrar>* _registrar;
  // Used for the temporary workaround for a bug that the camera is not properly positioned at
  // initialization. https://github.com/flutter/flutter/issues/24806
  // TODO(cyanglaz): Remove this temporary fix once the Maps SDK issue is resolved.
  // https://github.com/flutter/flutter/issues/27550
  BOOL _cameraDidInitialSetup;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
                    registrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  if ([super init]) {
    _viewId = viewId;

    GMSCameraPosition* camera = toOptionalCameraPosition(args[@"initialCameraPosition"]);
    _mapView = [GMSMapView mapWithFrame:frame camera:camera];
    _markers = [NSMutableDictionary dictionaryWithCapacity:1];
    _polygons = [NSMutableDictionary dictionaryWithCapacity:1];
    _trackCameraPosition = NO;
    interpretMapOptions(args[@"options"], self);
    NSString* channelName =
        [NSString stringWithFormat:@"plugins.flutter.io/google_maps_%lld", viewId];
    _channel = [FlutterMethodChannel methodChannelWithName:channelName
                                           binaryMessenger:registrar.messenger];
    __weak __typeof__(self) weakSelf = self;
    [_channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
      if (weakSelf) {
        [weakSelf onMethodCall:call result:result];
      }
    }];
    _mapView.delegate = weakSelf;
    _registrar = registrar;
    _cameraDidInitialSetup = NO;
  }
  return self;
}

- (UIView*)view {
  return _mapView;
}

- (void)onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"map#show"]) {
    [self showAtX:toDouble(call.arguments[@"x"]) Y:toDouble(call.arguments[@"y"])];
    result(nil);
  } else if ([call.method isEqualToString:@"map#hide"]) {
    [self hide];
    result(nil);
  } else if ([call.method isEqualToString:@"camera#animate"]) {
    [self animateWithCameraUpdate:toCameraUpdate(call.arguments[@"cameraUpdate"])];
    result(nil);
  } else if ([call.method isEqualToString:@"camera#move"]) {
    [self moveWithCameraUpdate:toCameraUpdate(call.arguments[@"cameraUpdate"])];
    result(nil);
  } else if ([call.method isEqualToString:@"map#update"]) {
    interpretMapOptions(call.arguments[@"options"], self);
    result(positionToJson([self cameraPosition]));
  } else if ([call.method isEqualToString:@"map#waitForMap"]) {
    result(nil);
  } else if ([call.method isEqualToString:@"marker#add"]) {
    NSDictionary* options = call.arguments[@"options"];
    NSString* markerId = [self addMarkerWithPosition:toLocation(options[@"position"])];
    interpretMarkerOptions(options, [self markerWithId:markerId], _registrar);
    result(markerId);
  } else if ([call.method isEqualToString:@"marker#update"]) {
    interpretMarkerOptions(call.arguments[@"options"],
                           [self markerWithId:call.arguments[@"marker"]], _registrar);
    result(nil);
  } else if ([call.method isEqualToString:@"marker#remove"]) {
    [self removeMarkerWithId:call.arguments[@"marker"]];
    result(nil);
  } else if ([call.method isEqualToString:@"polygon#add"]) {
    NSDictionary* options = call.arguments[@"options"];
    NSString* polygonId = [self addPolygonWithPath:toPath(options[@"points"])];
    interpretPolygonOptions(options, [self polygonWithId:polygonId], _registrar);
    result(polygonId);
  } else if ([call.method isEqualToString:@"polygon#update"]) {
    interpretPolygonOptions(call.arguments[@"options"],
                           [self polygonWithId:call.arguments[@"polygon"]], _registrar);
    result(nil);
  } else if ([call.method isEqualToString:@"polygon#remove"]) {
    [self removePolygonWithId:call.arguments[@"polygon"]];
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)showAtX:(CGFloat)x Y:(CGFloat)y {
  _mapView.frame =
      CGRectMake(x, y, CGRectGetWidth(_mapView.frame), CGRectGetHeight(_mapView.frame));
  _mapView.hidden = NO;
}

- (void)hide {
  _mapView.hidden = YES;
}

- (void)animateWithCameraUpdate:(GMSCameraUpdate*)cameraUpdate {
  [_mapView animateWithCameraUpdate:cameraUpdate];
}

- (void)moveWithCameraUpdate:(GMSCameraUpdate*)cameraUpdate {
  [_mapView moveCamera:cameraUpdate];
}

- (GMSCameraPosition*)cameraPosition {
  if (_trackCameraPosition) {
    return _mapView.camera;
  } else {
    return nil;
  }
}

- (NSString*)addMarkerWithPosition:(CLLocationCoordinate2D)position {
  FLTGoogleMapMarkerController* markerController =
      [[FLTGoogleMapMarkerController alloc] initWithPosition:position mapView:_mapView];
  _markers[markerController.markerId] = markerController;
  return markerController.markerId;
}

- (FLTGoogleMapMarkerController*)markerWithId:(NSString*)markerId {
  return _markers[markerId];
}

- (void)removeMarkerWithId:(NSString*)markerId {
  FLTGoogleMapMarkerController* markerController = _markers[markerId];
  if (markerController) {
    [markerController setVisible:NO];
    [_markers removeObjectForKey:markerId];
  }
}

- (NSString*)addPolygonWithPath:(GMSPath*)path {
  FLTGoogleMapPolygonController* polygonController =
      [[FLTGoogleMapPolygonController alloc] initWithPath:path mapView:_mapView];
  [polygonController setVisible:YES];
  _polygons[polygonController.polygonId] = polygonController;
  return polygonController.polygonId;
}

- (FLTGoogleMapPolygonController*)polygonWithId:(NSString*)polygonId {
  return _polygons[polygonId];
}

- (void)removePolygonWithId:(NSString*)polygonId {
  FLTGoogleMapPolygonController* polygonController = _polygons[polygonId];
  if (polygonController) {
    [polygonController setVisible:NO];
    [_polygons removeObjectForKey:polygonId];
  }
}

#pragma mark - FLTGoogleMapOptionsSink methods

- (void)setCamera:(GMSCameraPosition*)camera {
  _mapView.camera = camera;
}

- (void)setCameraTargetBounds:(GMSCoordinateBounds*)bounds {
  _mapView.cameraTargetBounds = bounds;
}

- (void)setCompassEnabled:(BOOL)enabled {
  _mapView.settings.compassButton = enabled;
}

- (void)setMapType:(GMSMapViewType)mapType {
  _mapView.mapType = mapType;
}

- (void)setMinZoom:(float)minZoom maxZoom:(float)maxZoom {
  [_mapView setMinZoom:minZoom maxZoom:maxZoom];
}

- (void)setRotateGesturesEnabled:(BOOL)enabled {
  _mapView.settings.rotateGestures = enabled;
}

- (void)setScrollGesturesEnabled:(BOOL)enabled {
  _mapView.settings.scrollGestures = enabled;
}

- (void)setTiltGesturesEnabled:(BOOL)enabled {
  _mapView.settings.tiltGestures = enabled;
}

- (void)setTrackCameraPosition:(BOOL)enabled {
  _trackCameraPosition = enabled;
}

- (void)setZoomGesturesEnabled:(BOOL)enabled {
  _mapView.settings.zoomGestures = enabled;
}

- (void)setMyLocationEnabled:(BOOL)enabled {
  _mapView.myLocationEnabled = enabled;
  _mapView.settings.myLocationButton = enabled;
}

#pragma mark - GMSMapViewDelegate methods

- (void)mapView:(GMSMapView*)mapView willMove:(BOOL)gesture {
  [_channel invokeMethod:@"camera#onMoveStarted" arguments:@{@"isGesture" : @(gesture)}];
}

- (void)mapView:(GMSMapView*)mapView didChangeCameraPosition:(GMSCameraPosition*)position {
  if (!_cameraDidInitialSetup) {
    // We suspected a bug in the iOS Google Maps SDK caused the camera is not properly positioned at
    // initialization. https://github.com/flutter/flutter/issues/24806
    // This temporary workaround fix is provided while the actual fix in the Google Maps SDK is
    // still being investigated.
    // TODO(cyanglaz): Remove this temporary fix once the Maps SDK issue is resolved.
    // https://github.com/flutter/flutter/issues/27550
    _cameraDidInitialSetup = YES;
    [mapView moveCamera:[GMSCameraUpdate setCamera:_mapView.camera]];
  }
  if (_trackCameraPosition) {
    [_channel invokeMethod:@"camera#onMove" arguments:@{@"position" : positionToJson(position)}];
  }
}

- (void)mapView:(GMSMapView*)mapView idleAtCameraPosition:(GMSCameraPosition*)position {
  [_channel invokeMethod:@"camera#onIdle" arguments:@{}];
}

- (BOOL)mapView:(GMSMapView*)mapView didTapMarker:(GMSMarker*)marker {
  NSString* markerId = marker.userData[0];
  [_channel invokeMethod:@"marker#onTap" arguments:@{@"marker" : markerId}];
  return [marker.userData[1] boolValue];
}

- (void)mapView:(GMSMapView*)mapView didTapInfoWindowOfMarker:(GMSMarker*)marker {
  NSString* markerId = marker.userData[0];
  [_channel invokeMethod:@"infoWindow#onTap" arguments:@{@"marker" : markerId}];
}

- (void)mapView:(GMSMapView*)mapView didTapOverlay:(GMSOverlay*)overlay {
  NSString* polygonId = overlay.userData[0];
  [_channel invokeMethod:@"polygon#onTap" arguments:@{@"polygon" : polygonId}];
}
@end

#pragma mark - Implementations of JSON conversion functions.

static id locationToJson(CLLocationCoordinate2D position) {
  return @[ @(position.latitude), @(position.longitude) ];
}

static id positionToJson(GMSCameraPosition* position) {
  if (!position) {
    return nil;
  }
  return @{
    @"target" : locationToJson([position target]),
    @"zoom" : @([position zoom]),
    @"bearing" : @([position bearing]),
    @"tilt" : @([position viewingAngle]),
  };
}

static bool toBool(id json) {
  NSNumber* data = json;
  return data.boolValue;
}

static int toInt(id json) {
  NSNumber* data = json;
  return data.intValue;
}

static double toDouble(id json) {
  NSNumber* data = json;
  return data.doubleValue;
}

static float toFloat(id json) {
  NSNumber* data = json;
  return data.floatValue;
}

static CLLocationCoordinate2D toLocation(id json) {
  NSArray* data = json;
  return CLLocationCoordinate2DMake(toDouble(data[0]), toDouble(data[1]));
}

static GMSPath* toPath(id json) {
  NSArray* data = json;
  GMSMutablePath* path = [GMSMutablePath path];
  for (NSArray* coordinate in data) {
    double latitude = [[coordinate firstObject] doubleValue];
    double longitude = [[coordinate lastObject] doubleValue];
    [path addCoordinate:CLLocationCoordinate2DMake(latitude, longitude)];
  }
  return path;
}

static UIColor* toUIColor(id json) {
  int rgbValue = toInt(json);
  return [[UIColor alloc] initWithRed: ((float)((rgbValue & 0xFF0000) >> 16)/255.0)
                                green: ((float)((rgbValue & 0xFF00) >> 8)/255.0)
                                 blue: ((float)(rgbValue & 0xFF)/255.0)
                                alpha: ((float)((rgbValue & 0xFF000000) >> 24)/255.0)];
}

static CGPoint toPoint(id json) {
  NSArray* data = json;
  return CGPointMake(toDouble(data[0]), toDouble(data[1]));
}

static GMSCameraPosition* toCameraPosition(id json) {
  NSDictionary* data = json;
  return [GMSCameraPosition cameraWithTarget:toLocation(data[@"target"])
                                        zoom:toFloat(data[@"zoom"])
                                     bearing:toDouble(data[@"bearing"])
                                viewingAngle:toDouble(data[@"tilt"])];
}

static GMSCameraPosition* toOptionalCameraPosition(id json) {
  return json ? toCameraPosition(json) : nil;
}

static GMSCoordinateBounds* toBounds(id json) {
  NSArray* data = json;
  return [[GMSCoordinateBounds alloc] initWithCoordinate:toLocation(data[0])
                                              coordinate:toLocation(data[1])];
}

static GMSCoordinateBounds* toOptionalBounds(id json) {
  NSArray* data = json;
  return (data[0] == [NSNull null]) ? nil : toBounds(data[0]);
}

static GMSMapViewType toMapViewType(id json) {
  int value = toInt(json);
  return (GMSMapViewType)(value == 0 ? 5 : value);
}

static GMSCameraUpdate* toCameraUpdate(id json) {
  NSArray* data = json;
  NSString* update = data[0];
  if ([update isEqualToString:@"newCameraPosition"]) {
    return [GMSCameraUpdate setCamera:toCameraPosition(data[1])];
  } else if ([update isEqualToString:@"newLatLng"]) {
    return [GMSCameraUpdate setTarget:toLocation(data[1])];
  } else if ([update isEqualToString:@"newLatLngBounds"]) {
    return [GMSCameraUpdate fitBounds:toBounds(data[1]) withPadding:toDouble(data[2])];
  } else if ([update isEqualToString:@"newLatLngZoom"]) {
    return [GMSCameraUpdate setTarget:toLocation(data[1]) zoom:toFloat(data[2])];
  } else if ([update isEqualToString:@"scrollBy"]) {
    return [GMSCameraUpdate scrollByX:toDouble(data[1]) Y:toDouble(data[2])];
  } else if ([update isEqualToString:@"zoomBy"]) {
    if (data.count == 2) {
      return [GMSCameraUpdate zoomBy:toFloat(data[1])];
    } else {
      return [GMSCameraUpdate zoomBy:toFloat(data[1]) atPoint:toPoint(data[2])];
    }
  } else if ([update isEqualToString:@"zoomIn"]) {
    return [GMSCameraUpdate zoomIn];
  } else if ([update isEqualToString:@"zoomOut"]) {
    return [GMSCameraUpdate zoomOut];
  } else if ([update isEqualToString:@"zoomTo"]) {
    return [GMSCameraUpdate zoomTo:toFloat(data[1])];
  }
  return nil;
}

static void interpretMapOptions(id json, id<FLTGoogleMapOptionsSink> sink) {
  NSDictionary* data = json;
  id cameraTargetBounds = data[@"cameraTargetBounds"];
  if (cameraTargetBounds) {
    [sink setCameraTargetBounds:toOptionalBounds(cameraTargetBounds)];
  }
  id compassEnabled = data[@"compassEnabled"];
  if (compassEnabled) {
    [sink setCompassEnabled:toBool(compassEnabled)];
  }
  id mapType = data[@"mapType"];
  if (mapType) {
    [sink setMapType:toMapViewType(mapType)];
  }
  id minMaxZoomPreference = data[@"minMaxZoomPreference"];
  if (minMaxZoomPreference) {
    NSArray* zoomData = minMaxZoomPreference;
    float minZoom = (zoomData[0] == [NSNull null]) ? kGMSMinZoomLevel : toFloat(zoomData[0]);
    float maxZoom = (zoomData[1] == [NSNull null]) ? kGMSMaxZoomLevel : toFloat(zoomData[1]);
    [sink setMinZoom:minZoom maxZoom:maxZoom];
  }
  id rotateGesturesEnabled = data[@"rotateGesturesEnabled"];
  if (rotateGesturesEnabled) {
    [sink setRotateGesturesEnabled:toBool(rotateGesturesEnabled)];
  }
  id scrollGesturesEnabled = data[@"scrollGesturesEnabled"];
  if (scrollGesturesEnabled) {
    [sink setScrollGesturesEnabled:toBool(scrollGesturesEnabled)];
  }
  id tiltGesturesEnabled = data[@"tiltGesturesEnabled"];
  if (tiltGesturesEnabled) {
    [sink setTiltGesturesEnabled:toBool(tiltGesturesEnabled)];
  }
  id trackCameraPosition = data[@"trackCameraPosition"];
  if (trackCameraPosition) {
    [sink setTrackCameraPosition:toBool(trackCameraPosition)];
  }
  id zoomGesturesEnabled = data[@"zoomGesturesEnabled"];
  if (zoomGesturesEnabled) {
    [sink setZoomGesturesEnabled:toBool(zoomGesturesEnabled)];
  }
  id myLocationEnabled = data[@"myLocationEnabled"];
  if (myLocationEnabled) {
    [sink setMyLocationEnabled:toBool(myLocationEnabled)];
  }
}

static void interpretMarkerOptions(id json, id<FLTGoogleMapMarkerOptionsSink> sink,
                                   NSObject<FlutterPluginRegistrar>* registrar) {
  NSDictionary* data = json;
  id alpha = data[@"alpha"];
  if (alpha) {
    [sink setAlpha:toFloat(alpha)];
  }
  id anchor = data[@"anchor"];
  if (anchor) {
    [sink setAnchor:toPoint(anchor)];
  }
  id draggable = data[@"draggable"];
  if (draggable) {
    [sink setDraggable:toBool(draggable)];
  }
  id icon = data[@"icon"];
  if (icon) {
    NSArray* iconData = icon;
    UIImage* image;
    if ([iconData[0] isEqualToString:@"defaultMarker"]) {
      CGFloat hue = (iconData.count == 1) ? 0.0f : toDouble(iconData[1]);
      image = [GMSMarker markerImageWithColor:[UIColor colorWithHue:hue / 360.0
                                                         saturation:1.0
                                                         brightness:0.7
                                                              alpha:1.0]];
    } else if ([iconData[0] isEqualToString:@"fromAsset"]) {
      if (iconData.count == 2) {
        image = [UIImage imageNamed:[registrar lookupKeyForAsset:iconData[1]]];
      } else {
        image = [UIImage imageNamed:[registrar lookupKeyForAsset:iconData[1]
                                                     fromPackage:iconData[2]]];
      }
    }
    [sink setIcon:image];
  }
  id flat = data[@"flat"];
  if (flat) {
    [sink setFlat:toBool(flat)];
  }
  id infoWindowAnchor = data[@"infoWindowAnchor"];
  if (infoWindowAnchor) {
    [sink setInfoWindowAnchor:toPoint(infoWindowAnchor)];
  }
  id infoWindowText = data[@"infoWindowText"];
  if (infoWindowText) {
    NSArray* infoWindowTextData = infoWindowText;
    NSString* title = (infoWindowTextData[0] == [NSNull null]) ? nil : infoWindowTextData[0];
    NSString* snippet = (infoWindowTextData[1] == [NSNull null]) ? nil : infoWindowTextData[1];
    [sink setInfoWindowTitle:title snippet:snippet];
  }
  id position = data[@"position"];
  if (position) {
    [sink setPosition:toLocation(position)];
  }
  id rotation = data[@"rotation"];
  if (rotation) {
    [sink setRotation:toDouble(rotation)];
  }
  id visible = data[@"visible"];
  if (visible) {
    [sink setVisible:toBool(visible)];
  }
  id zIndex = data[@"zIndex"];
  if (zIndex) {
    [sink setZIndex:toInt(zIndex)];
  }
}

static void interpretPolygonOptions(id json, id<FLTGoogleMapPolygonOptionsSink> sink,
                                   NSObject<FlutterPluginRegistrar>* registrar) {
  NSDictionary* data = json;
  id clickable = data[@"clickable"];
  if (clickable) {
    [sink setClickable:toBool(clickable)];
  }
  id fillColor = data[@"fillColor"];
  if (fillColor) {
    [sink setFillColor:toUIColor(fillColor)];
  }
  id strokeColor = data[@"strokeColor"];
  if (strokeColor) {
    [sink setStrokeColor:toUIColor(strokeColor)];
  }
  id strokeWidth = data[@"strokeWidth"];
  if (strokeWidth) {
    [sink setStrokeWidth:toDouble(strokeWidth)];
  }
}
