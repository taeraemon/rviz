// Copyright (c) 2018, Bosch Software Innovations GmbH.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in the
//      documentation and/or other materials provided with the distribution.
//
//    * Neither the name of the copyright holder nor the names of its
//      contributors may be used to endorse or promote products derived from
//      this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.


#include <gmock/gmock.h>

#include <memory>

#include <QApplication>  // NOLINT cpplint cannot handle include order
#include <QKeyEvent>  // NOLINT cpplint cannot handle include order

#include <OgreCamera.h>
#include <OgreRoot.h>
#include <OgreSceneManager.h>

#include "rviz_common/render_panel.hpp"
#include "rviz_common/viewport_mouse_event.hpp"

#include "rviz_default_plugins/view_controllers/xy_orbit/xy_orbit_view_controller.hpp"
#include "rviz_default_plugins/view_controllers/orbit/orbit_view_controller.hpp"
#include "rviz_default_plugins/view_controllers/ortho/fixed_orientation_ortho_view_controller.hpp"

#include "../../displays/display_test_fixture.hpp"
#include "../../mock_view_picker.hpp"
#include "../../scene_graph_introspection.hpp"
#include "../view_controller_test_fixture.hpp"

using namespace ::testing;  // NOLINT

class OrbitViewControllerTestFixture : public ViewControllerTestFixture
{
public:
  OrbitViewControllerTestFixture()
  {
    view_picker_ = std::make_shared<MockViewPicker>();
    EXPECT_CALL(*context_, getViewPicker()).WillRepeatedly(Return(view_picker_));

    orbit_ = std::make_shared<rviz_default_plugins::view_controllers::OrbitViewController>();
    orbit_->initialize(context_.get());
    testing_environment_->createOgreRenderWindow()->addViewport(orbit_->getCamera());
    setOSIndependentDimensions(orbit_->getCamera()->getViewport(), 10, 10);
  }

  void dragMouse(
    int to_x, int to_y, int from_x, int from_y,
    Qt::MouseButton button, Qt::KeyboardModifiers modifiers = Qt::NoModifier)
  {
    dragMouseInViewport(orbit_, to_x, to_y, from_x, from_y, button, modifiers);
  }

  void setCameraToDefaultYawPitch()
  {
    auto yaw_property = orbit_->childAt(7);
    auto pitch_property = orbit_->childAt(8);
    yaw_property->setValue(0);  // set to zero to make result easier to check
    pitch_property->setValue(0.5f);  // set to 0.5, because setting it to 0 can cause problems
    auto zero = std::chrono::nanoseconds::zero();
    orbit_->update(zero, zero);
  }

  Ogre::Vector3 cameraPosition()
  {
    return orbit_->getCamera()->getParentSceneNode()->getPosition();
  }

  Ogre::Vector3 inCameraFrame(const Ogre::Vector3 & point)
  {
    auto node = orbit_->getCamera()->getParentSceneNode();
    return node->getOrientation().Inverse() * (point - node->getPosition());
  }

  void update()
  {
    auto zero = std::chrono::nanoseconds::zero();
    orbit_->update(zero, zero);
  }

  std::shared_ptr<MockViewPicker> view_picker_;
  std::shared_ptr<rviz_default_plugins::view_controllers::OrbitViewController> orbit_;
};

MATCHER_P(Vector3Near, expected, "") {
  return arg.distance(expected) < 0.001f;
}

TEST_F(OrbitViewControllerTestFixture, moving_the_mouse_to_the_left_rotates_left)
{
  setCameraToDefaultYawPitch();

  auto yaw_property = orbit_->childAt(7);
  auto pitch_property = orbit_->childAt(8);

  EXPECT_THAT(yaw_property->getNameStd(), StrEq("Yaw"));
  EXPECT_THAT(pitch_property->getNameStd(), StrEq("Pitch"));
  EXPECT_THAT(yaw_property->getValue().toFloat(), FloatNear(0, 0.001f));
  EXPECT_THAT(pitch_property->getValue().toFloat(), FloatNear(0.5, 0.001f));

  dragMouse(0, 10, 10, 10, Qt::LeftButton);

  EXPECT_THAT(yaw_property->getValue().toFloat(), FloatNear(0.05f, 0.001f));
  EXPECT_THAT(pitch_property->getValue().toFloat(), FloatNear(0.5, 0.001f));
}

TEST_F(OrbitViewControllerTestFixture, moving_the_mouse_up_rotates_up)
{
  setCameraToDefaultYawPitch();

  auto yaw_property = orbit_->childAt(7);
  auto pitch_property = orbit_->childAt(8);

  EXPECT_THAT(yaw_property->getNameStd(), StrEq("Yaw"));
  EXPECT_THAT(pitch_property->getNameStd(), StrEq("Pitch"));
  EXPECT_THAT(yaw_property->getValue().toFloat(), FloatNear(0, 0.001f));
  EXPECT_THAT(pitch_property->getValue().toFloat(), FloatNear(0.5, 0.001f));

  dragMouse(10, 20, 10, 10, Qt::LeftButton);

  EXPECT_THAT(yaw_property->getValue().toFloat(), FloatNear(0, 0.001f));
  EXPECT_THAT(pitch_property->getValue().toFloat(), FloatNear(0.55f, 0.001f));
}

// The mock view picker reports a point only for a patch starting at the given pixel. The
// controller searches a patch around the cursor, which starts at (0, 0) for a cursor near
// the top left corner.
TEST_F(OrbitViewControllerTestFixture, navigate_at_cursor_wheel_zooms_towards_the_point_below_it)
{
  setCameraToDefaultYawPitch();
  orbit_->subProp("Navigate At Cursor")->setValue(true);
  Ogre::Vector3 point(1.0f, 0.5f, -0.5f);
  view_picker_->registerObject({0, 0, point});
  auto position = cameraPosition();

  auto event = generateMouseWheelEvent(120);
  orbit_->handleMouseEvent(event);
  update();

  EXPECT_THAT(cameraPosition(), Vector3Near(point + (position - point) * std::exp(-0.12f)));
}

TEST_F(OrbitViewControllerTestFixture, navigate_at_cursor_wheel_does_not_stop_in_empty_space)
{
  setCameraToDefaultYawPitch();
  orbit_->subProp("Navigate At Cursor")->setValue(true);
  auto position = cameraPosition();

  for (int i = 0; i < 40; ++i) {
    auto event = generateMouseWheelEvent(120);
    orbit_->handleMouseEvent(event);
  }
  update();

  // Without Navigate At Cursor the camera can only approach the focal point, 10 away.
  EXPECT_THAT(cameraPosition().distance(position), Gt(20.0f));
  EXPECT_THAT(orbit_->childAt(4)->getValue().toFloat(), FloatNear(10.0f, 0.001f));
}

TEST_F(OrbitViewControllerTestFixture, navigate_at_cursor_rotates_around_the_point_below_it)
{
  setCameraToDefaultYawPitch();
  orbit_->subProp("Navigate At Cursor")->setValue(true);
  Ogre::Vector3 point(1.0f, 0.5f, -0.5f);
  view_picker_->registerObject({0, 0, point});
  auto point_in_camera = inCameraFrame(point);

  dragMouse(5, 0, 2, 2, Qt::LeftButton);
  update();

  EXPECT_THAT(orbit_->childAt(7)->getValue().toFloat(), Not(FloatNear(0.0f, 0.001f)));
  EXPECT_THAT(inCameraFrame(point), Vector3Near(point_in_camera));
}

TEST_F(OrbitViewControllerTestFixture, moving_the_wheel_zooms) {
  auto distance_property = orbit_->childAt(4);
  EXPECT_THAT(distance_property->getNameStd(), StrEq("Distance"));
  EXPECT_THAT(distance_property->getValue().toFloat(), FloatNear(10, 0.001f));

  auto event = generateMouseWheelEvent(100);
  orbit_->handleMouseEvent(event);

  EXPECT_THAT(distance_property->getValue().toFloat(), FloatNear(9, 0.001f));
}

TEST_F(OrbitViewControllerTestFixture, moving_the_mouse_with_right_button_zooms) {
  auto distance_property = orbit_->childAt(4);
  EXPECT_THAT(distance_property->getNameStd(), StrEq("Distance"));
  EXPECT_THAT(distance_property->getValue().toFloat(), FloatNear(10, 0.001f));

  dragMouse(10, 20, 10, 10, Qt::RightButton);

  EXPECT_THAT(distance_property->getValue().toFloat(), FloatNear(11, 0.001f));
}

TEST_F(OrbitViewControllerTestFixture, moving_the_mouse_with_shift_and_left_moves_position) {
  setCameraToDefaultYawPitch();

  auto x_property = orbit_->childAt(9)->childAt(0);
  EXPECT_THAT(x_property->getNameStd(), StrEq("X"));
  auto y_property = orbit_->childAt(9)->childAt(1);
  EXPECT_THAT(y_property->getNameStd(), StrEq("Y"));
  auto z_property = orbit_->childAt(9)->childAt(2);
  EXPECT_THAT(z_property->getNameStd(), StrEq("Z"));
  EXPECT_THAT(x_property->getValue().toFloat(), FloatNear(0, 0.001f));
  EXPECT_THAT(y_property->getValue().toFloat(), FloatNear(0, 0.001f));
  EXPECT_THAT(z_property->getValue().toFloat(), FloatNear(0, 0.001f));

  dragMouse(10, 10, 0, 0, Qt::LeftButton, Qt::ShiftModifier);

  EXPECT_THAT(x_property->getValue().toFloat(), FloatNear(-3.97168f, 0.001f));
  EXPECT_THAT(y_property->getValue().toFloat(), FloatNear(-11.0457f, 0.001f));
  EXPECT_THAT(z_property->getValue().toFloat(), FloatNear(7.27013f, 0.001f));
}

TEST_F(
  OrbitViewControllerTestFixture,
  mimic_does_not_change_view_when_given_any_orbit_view_controller)
{
  auto xy_orbit_view =
    std::make_shared<rviz_default_plugins::view_controllers::XYOrbitViewController>();
  xy_orbit_view->setClassId("rviz_default_plugins/XYOrbit");
  xy_orbit_view->initialize(context_.get());
  auto old_yaw_property = xy_orbit_view->childAt(7);
  auto old_pitch_property = xy_orbit_view->childAt(8);
  old_yaw_property->setValue(0);
  old_pitch_property->setValue(0.5f);
  xy_orbit_view->move(10, 12, 0);
  auto zero = std::chrono::nanoseconds::zero();
  xy_orbit_view->update(zero, zero);

  orbit_->mimic(xy_orbit_view.get());
  orbit_->update(zero, zero);

  auto yaw_property = orbit_->childAt(7);
  auto pitch_property = orbit_->childAt(8);
  EXPECT_THAT(yaw_property->getValue().toFloat(), FloatNear(0, 0.001f));
  EXPECT_THAT(pitch_property->getValue().toFloat(), FloatNear(0.5f, 0.001f));
}

TEST_F(
  OrbitViewControllerTestFixture,
  mimic_keeps_focal_point_and_view_from_top_down_ortho_view_controller)
{
  auto ortho_view =
    std::make_shared<rviz_default_plugins::view_controllers::FixedOrientationOrthoViewController>();
  ortho_view->setClassId("rviz_default_plugins/TopDownOrtho");
  ortho_view->initialize(context_.get());
  ortho_view->move(10, 12);
  auto zero = std::chrono::nanoseconds::zero();
  // ortho_view->update(zero, zero);
  auto old_x_value = ortho_view->childAt(6)->getValue().toFloat();
  auto old_y_value = ortho_view->childAt(7)->getValue().toFloat();

  orbit_->mimic(ortho_view.get());
  orbit_->update(zero, zero);

  auto yaw_property = orbit_->childAt(7);
  auto pitch_property = orbit_->childAt(8);
  auto x_property = orbit_->childAt(9)->childAt(0);
  auto y_property = orbit_->childAt(9)->childAt(1);
  auto z_property = orbit_->childAt(9)->childAt(2);
  EXPECT_THAT(yaw_property->getValue().toFloat(), FloatNear(-1.5708f, 0.001f));
  EXPECT_THAT(pitch_property->getValue().toFloat(), FloatNear(1.5698f, 0.001f));
  EXPECT_THAT(x_property->getValue().toFloat(), FloatNear(old_x_value, 0.001f));
  EXPECT_THAT(y_property->getValue().toFloat(), FloatNear(old_y_value, 0.001f));
  EXPECT_THAT(z_property->getValue().toFloat(), FloatNear(0, 0.001f));
}

TEST_F(OrbitViewControllerTestFixture, mimic_does_not_move_camera_when_given_same_class_controller)
{
  auto old_orbit_view =
    std::make_shared<rviz_default_plugins::view_controllers::OrbitViewController>();
  old_orbit_view->setClassId("rviz_default_plugins/Orbit");
  old_orbit_view->initialize(context_.get());
  auto old_yaw_property = old_orbit_view->childAt(7);
  auto old_pitch_property = old_orbit_view->childAt(8);
  old_yaw_property->setValue(0);
  old_pitch_property->setValue(0.5f);
  old_orbit_view->move(10, 10, 10);
  auto zero = std::chrono::nanoseconds::zero();
  old_orbit_view->update(zero, zero);
  auto old_x_value = old_orbit_view->childAt(9)->childAt(0)->getValue().toFloat();
  auto old_y_value = old_orbit_view->childAt(9)->childAt(1)->getValue().toFloat();
  auto old_z_value = old_orbit_view->childAt(9)->childAt(2)->getValue().toFloat();

  orbit_->mimic(old_orbit_view.get());
  orbit_->update(zero, zero);

  auto x_property = orbit_->childAt(9)->childAt(0);
  auto y_property = orbit_->childAt(9)->childAt(1);
  auto z_property = orbit_->childAt(9)->childAt(2);
  auto yaw_property = orbit_->childAt(7);
  auto pitch_property = orbit_->childAt(8);
  EXPECT_THAT(x_property->getValue().toFloat(), FloatNear(old_x_value, 0.001f));
  EXPECT_THAT(y_property->getValue().toFloat(), FloatNear(old_y_value, 0.001f));
  EXPECT_THAT(z_property->getValue().toFloat(), FloatNear(old_z_value, 0.001f));
  EXPECT_THAT(yaw_property->getValue().toFloat(), FloatNear(0, 0.001f));
  EXPECT_THAT(pitch_property->getValue().toFloat(), FloatNear(0.5f, 0.001f));
}

int main(int argc, char ** argv)
{
  QApplication app(argc, argv);
  InitGoogleMock(&argc, argv);
  return RUN_ALL_TESTS();
}
