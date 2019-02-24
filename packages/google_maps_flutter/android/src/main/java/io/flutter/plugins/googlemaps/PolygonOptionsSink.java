// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.googlemaps;

import java.util.List;

import com.google.android.gms.maps.model.LatLng;

/** Receiver of Polygon configuration options. */
interface PolygonOptionsSink {
  void setClickable(boolean clickable);
  void setFillColor(int color);
  void setPoints(List<LatLng> points);
  void setStrokeColor(int color);
}
