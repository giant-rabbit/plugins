// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Flutter/Flutter.h>
#import <GoogleMaps/GoogleMaps.h>

// Defines polygon UI options writable from Flutter.
@protocol FLTGoogleMapPolygonOptionsSink
- (void)setClickable:(BOOL)clickable;
- (void)setFillColor:(UIColor*)fillColor;
- (void)setStrokeColor:(UIColor*)strokeColor;
- (void)setStrokeWidth:(CGFloat)strokeWidth;
- (void)setPath:(GMSPath*)path;
- (void)setVisible:(BOOL)visible;
@end

// Defines polygon controllable by Flutter.
@interface FLTGoogleMapPolygonController : NSObject <FLTGoogleMapPolygonOptionsSink>
@property(atomic, readonly) NSString* polygonId;
- (instancetype)initWithPath:(GMSPath*)path mapView:(GMSMapView*)mapView;
@end
