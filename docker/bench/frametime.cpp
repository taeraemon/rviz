// LD_PRELOAD shim: times every Ogre::Root::renderOneFrame() call (CPU submit + GPU work,
// since the VirtualGL swap reads the frame back) and writes "<unix time> <ms>" lines to
// $FRAMETIME_OUT.
#include <dlfcn.h>
#include <chrono>
#include <cstdio>
#include <cstdlib>

namespace Ogre { class Root { public: bool renderOneFrame(); }; }

bool Ogre::Root::renderOneFrame()
{
  using Fn = bool (*)(Ogre::Root *);
  static Fn real = reinterpret_cast<Fn>(dlsym(RTLD_NEXT, "_ZN4Ogre4Root14renderOneFrameEv"));
  static FILE * out = std::fopen(std::getenv("FRAMETIME_OUT") ? std::getenv("FRAMETIME_OUT") : "/dev/stderr", "w");
  auto t0 = std::chrono::steady_clock::now();
  bool r = real(this);
  double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
  std::fprintf(
    out, "%.3f %.3f\n",
    std::chrono::duration<double>(std::chrono::system_clock::now().time_since_epoch()).count(), ms);
  std::fflush(out);
  return r;
}
