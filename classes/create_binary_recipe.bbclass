# 
# This class is used for automating the creation of binary distribution 
# recipes. By distributing these recipes instead of the source recipes
# the software can be used in Yocto without having to distribute the 
# source code.
#
# Set BINARY_OVERLAY_ENABLED = "1" in local.conf to enable
#
# TODOs: 
# - layer.conf is overwritten by each recipe, maybe this can be improved
# - See if the WARNING about overriding RDEPENDS_* can be addressed
# - Test, test, test

# Set up the target destination
# By default the layer will be in /tmp/meta-mybinarylayer

BINARY_OVERLAY_DEST ?= "/tmp/"
BINARY_OVERLAY_NAME ?= "mybinarylayer"

do_package[vardeps] += "cbr_package_binaries"
do_package[postfuncs] += "cbr_package_binaries"

python cbr_package_binaries() {
    # Create the binary overlay directory structure and recipe
    import os, errno

    def find_relative_path(d):
        # Find the relative path of the recipe so we can create the same layout
        
        layers = bb.data.getVar('BBLAYERS', d, 1).strip().split(' ')
        recipe = bb.data.getVar('FILE', d, 1)
        for layer in layers:
            if recipe.startswith(layer):
                # We found the correct layer
                # Separate path from file and return
                parts = recipe[len(layer):].split('/')
                dir = '/'.join(parts[1:len(parts)-1])
                file = ''.join(parts[len(parts)-1:])
                return (dir, file)
        return (None, None)

    def create_tar_gz(tarname, dirname):
        import os
        import tarfile

        packages = ""
        # Create a tarball of contents of dirname
        predir = os.getcwd()
        os.chdir(dirname)
        
        tar = tarfile.open(tarname, "w:gz")
        for f in os.listdir("."):
            # exclude -dbg which contains src
            if not f.endswith("-dbg"):
                tar.add(f)
                if os.path.isdir(os.path.join(dirname, f)):
                    packages += " " + f
        tar.close()
        os.chdir(predir)
        return packages

    def create_dir(dir):
        # Create a directory
        import os
        import errno
        
        try:
            os.makedirs(dir)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise  # Raise all other errors

    def create_recipe(file_inc_path, src_uri, packages, d):
        # Create a recipe file
        recipe = ""

        # Copy over some variables from source recipe
        carry_over = "DESCRIPTION PR SECTION HOMEPAGE DEPENDS"
        
        for var in carry_over.split(" "):
            var_value = bb.data.getVar(var, d, 1)
            if var_value:
                recipe += var + " = \"" + var_value + "\"\n"

        # Set LICENSE to CLOSED
        recipe += "LICENSE = \"CLOSED\"\n"

        # Copy over all RDEPENDS_* variables
        for var in bb.data.keys(d):
            if var.startswith("RDEPENDS"):
                var_value = bb.data.getVar(var, d, 1)
                if var_value:
                    recipe += var + " = \"" + var_value + "\"\n"

        # Copy over all RPROVIDES_* variables
        for var in bb.data.keys(d):
            if var.startswith("RPROVIDES"):
                var_value = bb.data.getVar(var, d, 1)
                if var_value:
                    recipe += var + " = \"" + var_value + "\"\n"
        
        # Set SRC_URI
        recipe += "SRC_URI = \"" + src_uri + "\"\n"

        # Set PACKAGES
        # Make sure to use any renaming e.g. by debian.bbclass by checking
        # PKG_pn
        pkgs = ""
        for pkg in packages.split(" "):
            pkgname = bb.data.getVar('PKG_' + pkg.strip(), d, 1)
            if not pkgname:
                pkgname = pkg.strip()
            pkgs += " " + pkgname
        recipe += "PACKAGES = \"" + pkgs + "\"\n"

        # If DEBIAN_NAMES = 1 we need to inherit debian.bbclass to make sure
        # the packages on "target" side is also renamed.
        if ( int(bb.data.getVar('DEBIAN_NAMES', d, 1)) == 1):
            recipe += "inherit debian\n"

        # Inherit the class that binary overlays on the target side
        recipe += "inherit binary_recipe\n"

        # Allow empty packages (needed for packagegroups)
        recipe += "ALLOW_EMPTY_${PN} = \"1\"\n"
        
        with open(file_inc_path, "w") as f:
            f.write(recipe)

    def create_layer_conf(layer_conf_file, name):
        # Create a layer configuration file
        config = ""
        config += '# We have a conf and classes directory, append to BBPATH\n'
        config += 'BBPATH .= ":${LAYERDIR}"\n'
        config += '# We have a recipes directory, add to BBFILES\n'
        config += 'BBFILES += "${LAYERDIR}/recipes-*/*/*.bb ${LAYERDIR}/recipes-*/*/*.bbappend"\n'
        config += 'BBFILE_COLLECTIONS += "' + name + '-layer"\n'
        config += 'BBFILE_PATTERN_' + name + '-layer := "^${LAYERDIR}/"\n'
        config += 'BBFILE_PRIORITY_' + name + '-layer = "7"'
        
        with open(layer_conf_file, "w") as f:
            f.write(config)

    # Make sure feature is enabled before doing anything
    enabled = bb.data.getVar('BINARY_OVERLAY_ENABLED', d, 1)
    if not enabled or int(enabled) != 1:
        return

    # Create directories
    dir, file = find_relative_path(d)
    layerdest = bb.data.getVar('BINARY_OVERLAY_DEST', d, 1)
    layername = bb.data.getVar('BINARY_OVERLAY_NAME', d, 1)
    layer = layerdest + "/meta-" + layername
    _ = create_dir(layer + "/" + dir + "/files")
    _ = create_dir(layer + "/conf")

    # Create the layer configuration file
    _ = create_layer_conf(layer + "/conf/layer.conf", layername)

    # After the package is built, create a tarball containing the result

    workdir = bb.data.getVar('WORKDIR', d, 1)
    package_name = bb.data.getVar('PN', d, 1)
    package_split_dir = workdir + "/packages-split"

    # Find where to put file
    file_path = layerdest + "/meta-" + layername + "/" + dir + "/files/"

    # Create tarball
    packages = create_tar_gz(file_path + package_name + ".tar.gz", package_split_dir)

    # Create the recipe
    src_uri = "file://" + bb.data.getVar('PN', d, 1) + ".tar.gz;subdir=binary-split"
    _ = create_recipe(layer + "/" + dir + "/" + file, src_uri, packages, d)

}

