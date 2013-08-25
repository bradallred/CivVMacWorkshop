/* CivVMacWorkshop - Civilization V launch wrapper that will install mods downloaded from Steam Workshop for Mac OS X
 * Copyright (C) 2013 Brad Allred
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#define STEAMWORKS_CLIENT_INTERFACES

#include "SteamAPI.h"
#include "SteamclientAPI.h"

#import "LZMAExtractor.h"

#import <AppKit/NSWorkspace.h>

bool (*steamInit) (); // SteamAPI_Init()
void (*steamShutdown) (); // SteamAPI_Shutdown()
ISteamUser013* (*getUser) (); // SteamUser()

int main(int argc, const char * argv[])
{
	@autoreleasepool {
		NSLog(@"Workshop mod installer launched...");
		// get the URL for Civ V
		CFURLRef url;
		OSStatus err = LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.aspyr.civ5xp.steam"), NULL, NULL, &url);

		NSBundle* civ = [NSBundle bundleWithURL:(NSURL*)url];
		NSString* dylibPath = [civ pathForAuxiliaryExecutable:@"libsteam_api.dylib"];

		void* handle = dlopen([dylibPath fileSystemRepresentation], RTLD_NOW);
		steamInit = (bool (*)())dlsym(handle, "SteamAPI_Init");
		steamShutdown = (void (*)())dlsym(handle, "SteamAPI_Shutdown");
		getUser = (ISteamUser013* (*)())dlsym(handle, "SteamUser");

		if ((*steamInit)()) {
			ISteamUser013* user = (*getUser)();
			if (user) {
				char dataDir[PATH_MAX];
				user->GetUserDataFolder(dataDir, PATH_MAX);

				NSString* modPath = [NSString stringWithCString:dataDir encoding:NSASCIIStringEncoding];
				modPath = [modPath stringByDeletingLastPathComponent];
				modPath = [modPath stringByDeletingLastPathComponent];
				modPath = [modPath stringByAppendingPathComponent:@"ugc"];

				NSFileManager* fm = [NSFileManager defaultManager];
				NSError* error = nil;
				NSArray* paths = [fm subpathsOfDirectoryAtPath:modPath error:&error];
				NSArray* mods = [paths pathsMatchingExtensions:@[@"civ5mod"]];

				NSArray* docDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
				NSString* docDir = [docDirs objectAtIndex:0];
				NSString* installDir = [docDir stringByAppendingFormat:@"/Aspyr/Sid Meier's Civilization 5/MODS"];

				[fm createDirectoryAtPath:installDir withIntermediateDirectories:YES attributes:nil error:&error];

				for (NSString* mod in mods) {
					NSString* modName = [[mod lastPathComponent] stringByDeletingPathExtension];
					NSLog(@"installing %@ to %@", modName, installDir);
					[LZMAExtractor extract7zArchive:[modPath stringByAppendingFormat:@"/%@", mod]
											dirName:[installDir stringByAppendingPathComponent:modName]
										preserveDir:YES];
					// TODO: delete the archive now?
				}
				NSWorkspace* ws = [NSWorkspace sharedWorkspace];
				NSURL* steamURL = [NSURL URLWithString:@"steam://run/8930"];
				[ws openURL:steamURL];
			} else {
				NSLog(@"couldn't get the Steam User");
			}
		} else {
			NSLog(@"steam api initialization failed!");
		}

		// close up shop
		(*steamShutdown)();
		dlclose(handle);
	}
    return 0;
}

