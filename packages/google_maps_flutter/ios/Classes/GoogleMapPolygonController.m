// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "GoogleMapPolygonController.h"

static uint64_t _nextPolygonId = 0;

@implementation FLTGoogleMapPolygonController {
  GMSPolygon* _polygon;
  GMSMapView* _mapView;
}
- (instancetype)initWithPath:(GMSPath*)path mapView:(GMSMapView*)mapView {
  self = [super init];
  if (self) {
    _polygon = [GMSPolygon polygonWithPath:path];
    _mapView = mapView;
    _polygonId = [NSString stringWithFormat:@"%lld", _nextPolygonId++];
    _polygon.userData = @[ _polygonId, @(NO) ];
  }
  return self;
}

#pragma mark - FLTGoogleMapPolygonOptionsSink methods

- (void)setClickable:(BOOL)clickable {
  _polygon.tappable = clickable;
}
- (void)setFillColor:(UIColor*)fillColor {
  _polygon.fillColor = fillColor;
}
- (void)setStrokeColor:(UIColor*)strokeColor {
  _polygon.strokeColor = strokeColor;
}
- (void)setPath:(GMSPath*)path {
  _polygon.path = path;
}
- (void)setVisible:(BOOL)visible {
  _polygon.map = visible ? _mapView : nil;
}
@end
