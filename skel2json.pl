#!/usr/bin/perl -w

$| = 1;
use strict;
use JSON;

my $params = @ARGV;
if ($params < 1)
{
	print "Usage:\n\tskel2json.pl <file1.skel file2.skel file3.skel ...>\n\n";
}
foreach my $param (@ARGV)
{
	if (-e $param)
	{
		my $filename = substr($param, 0, rindex($param, '.')) . '.json';
		ConvertSkel($param, $filename);
	}
	else
	{
		print "Error: $param does not exist.\n";
	}
}

sub ConvertSkel
{
	my ($filename, $fileout) = @_;
	my $filesize = -s $filename;
	my $skeldata;
	print "Converting $filename to $fileout ... ";
	open(SKELFILE, '<' . $filename);
	binmode(SKELFILE);
	read(SKELFILE, $skeldata, $filesize);
	close(SKELFILE);
	if ((length($skeldata) != $filesize))
	{
		print "Read error!\n";
	}
	else
	{
		my $pointer = 0;
		my $num;
		my $nonessential;
		my %json;
		my %skeleton;
		my @bones;
		my @slots;
		my %skins;
		my %animations;
		my @bonename;
		my @slotname;
		my @skinname;

		# Skeleton section.
		$skeleton{'hash'} = readString($skeldata, $pointer);
		$skeleton{'spine'} = readString($skeldata, $pointer);
		if ($skeleton{'spine'} ne '3.1.08')
		{
			print "Wrong version!\n";
		}
		else
		{
			$skeleton{'width'} = readFloat($skeldata, $pointer);
			$skeleton{'height'} = readFloat($skeldata, $pointer);
			$nonessential = readByte($skeldata, $pointer); # boolean
			if ($nonessential)
			{
				$skeleton{'fps'} = readFloat($skeldata, $pointer);
				$skeleton{'images'} = readString($skeldata, $pointer);
			}

			# Bones section.
			$num = readVarint($skeldata, $pointer);
			for (my $boneid = 0; $boneid < $num; $boneid++)
			{
				my %bone;
				$bone{'name'} = readString($skeldata, $pointer);
				$bonename[$boneid] = $bone{'name'};

				# Root bone has no parent.
				if ($boneid > 0)
				{
					my $parentid = readVarint($skeldata, $pointer);
					$bone{'parent'} = $bonename[$parentid];
				}
				$bone{'x'} = readFloat($skeldata, $pointer);
				$bone{'y'} = readFloat($skeldata, $pointer);
				$bone{'scaleX'} = readFloat($skeldata, $pointer);
				$bone{'scaleY'} = readFloat($skeldata, $pointer);
				$bone{'rotation'} = readFloat($skeldata, $pointer);
				$bone{'length'} = readFloat($skeldata, $pointer);
				$bone{'inheritScale'} = readByte($skeldata, $pointer); # boolean
				$bone{'inheritRotation'} = readByte($skeldata, $pointer); # boolean
				if ($nonessential)
				{
					$bone{'color'} = readColor($skeldata, $pointer);
				}
				push @bones, \%bone;
			}

			# IK section.
			$num = readVarint($skeldata, $pointer);
			if ($num > 0)
			{
				die("TODO: IK section.");
			}

			# Transform section.
			$num = readVarint($skeldata, $pointer);
			if ($num > 0)
			{
				die("TODO: Transform section.");
			}

			# Slots section.
			$num = readVarint($skeldata, $pointer);
			my @blendmode = ('normal', 'additive', 'multiply', 'screen');
			for (my $slotid = 0; $slotid < $num; $slotid++)
			{
				my %slot;
				$slot{'name'} = readString($skeldata, $pointer);
				$slotname[$slotid] = $slot{'name'};
				my $boneid = readVarint($skeldata, $pointer);
				$slot{'bone'} = $bonename[$boneid];
				$slot{'color'} = readColor($skeldata, $pointer);
				$slot{'attachment'} = readString($skeldata, $pointer);
				my $blendid = readVarint($skeldata, $pointer);
				$slot{'blend'} = $blendmode[$blendid];
				push @slots, \%slot;
			}
			
			# Skins section.
			my %skin;
			%skin = readSkin($skeldata, $pointer, \@slotname, $nonessential);
			push @skinname, 'default';
			$skins{'default'} = \%skin;
			$num = readVarint($skeldata, $pointer);
			for (my $skinid = 0; $skinid < $num; $skinid++)
			{
				my $name = readString($skeldata, $pointer);
				push @skinname, $name;
				my %extraskin = readSkin($skeldata, $pointer, \@slotname, $nonessential);
				$skins{$name} = \%extraskin;
			}

			# Events section.
			$num = readVarint($skeldata, $pointer);
			if ($num > 0)
			{
				die("TODO: Events section.");
			}

			# Animations section.
			$num = readVarint($skeldata, $pointer);
			for (my $animid = 0; $animid < $num; $animid++)
			{
				my %animation;
				my $name = readString($skeldata, $pointer);
				%animation = readAnimation($skeldata, $pointer, \@slotname, \@bonename, \@skinname);
				$animations{$name} = \%animation;
			}

			# Put together the JSON file from the decoded sections.
			$json{'skeleton'} = \%skeleton;
			$json{'bones'} = \@bones;
			$json{'slots'} = \@slots;
			$json{'skins'} = \%skins;
			$json{'animations'} = \%animations;

			# Change the extension to .json and save the data.
			open (JSONFILE, '>' . $fileout);
			print JSONFILE encode_json \%json;
			close (JSONFILE);
			print "Done!\n";
		}
	}
}

sub readByte
{
	my ($rawdata, $pointer) = @_;
	my $value = unpack('C', substr($rawdata, $pointer, 1));
	$_[1] = $pointer + 1;
	return $value;
}

sub readColor
{
	my ($rawdata, $pointer) = @_;
	my $byte = readByte($rawdata, $pointer);
	my $color = sprintf("%02X", $byte);
	$byte = readByte($rawdata, $pointer);
	$color .= sprintf("%02X", $byte);
	$byte = readByte($rawdata, $pointer);
	$color .= sprintf("%02X", $byte);
	$byte = readByte($rawdata, $pointer);
	$color .= sprintf("%02X", $byte);
	$_[1] = $pointer;
	return $color;
}

sub readVarint
{
	my ($rawdata, $pointer) = @_;
	my $byte = readByte($rawdata, $pointer);
	my $value = $byte & 0x7F;
	if ($byte & 0x80)
	{
		$byte = readByte($rawdata, $pointer);
		$value |= ($byte & 0x7f) << 7;
		if ($byte & 0x80)
		{
			$byte = readByte($rawdata, $pointer);
			$value |= ($byte & 0x7f) << 14;
			if ($byte & 0x80)
			{
				$byte = readByte($rawdata, $pointer);
				$value |= ($byte & 0x7f) << 21;
				if ($byte & 0x80)
				{
					$byte = readByte($rawdata, $pointer);
					$value |= ($byte & 0x7f) << 28;
				}
			}
		}
	}
	$_[1] = $pointer;
	return $value;
}

sub readFloat
{
	my ($rawdata, $pointer) = @_;
	my $float = unpack('f', substr($rawdata, $pointer + 3, 1) . substr($rawdata, $pointer + 2, 1) . substr($rawdata, $pointer + 1, 1) . substr($rawdata, $pointer, 1));
	$_[1] = $pointer + 4;
	return $float;
}

sub readFloatArray
{
	my ($rawdata, $pointer, $count) = @_;
	my @array;
	for (my $i = 0; $i < $count; $i++)
	{
		push @array, readFloat($rawdata, $pointer);
	}
	$_[1] = $pointer;
	return @array;
}

sub readShort
{
	my ($rawdata, $pointer) = @_;
	my $short = unpack('n', substr($rawdata, $pointer, 2));
	$_[1] = $pointer + 2;
	return $short;
}

sub readShortArray
{
	my ($rawdata, $pointer) = @_;
	my @array;
	my $count = readVarint($rawdata, $pointer);
	for (my $i = 0; $i < $count; $i++)
	{
		push @array, readShort($rawdata, $pointer);
	}
	$_[1] = $pointer;
	return @array;
}

sub readString
{
	my ($rawdata, $pointer) = @_;
	my $strlen = readByte($rawdata, $pointer);
	if ($strlen == 0)
	{
		$_[1]++;
		return;
	}
	elsif ($strlen == 1)
	{
		$_[1]++;
		return '';
	}
	else
	{
		$_[1] = $pointer + $strlen - 1;
		return substr($rawdata, $pointer, $strlen - 1);
	}
}

sub readCurveType
{
	my ($rawdata, $pointer) = @_;
	my $type = readByte($rawdata, $pointer);
	if ($type == 0)
	{
		$type = 'linear';
	}
	elsif ($type == 1)
	{
		$type = 'stepped';
	}
	elsif ($type == 2)
	{
		$type = 'bezier';
	}
	else
	{
		die("Invalid curve type.\n");
	}
	$_[1] = $pointer;
	return $type;
}

sub readCurve
{
	my ($rawdata, $pointer) = @_;
	my @array;
	for (my $i = 0; $i < 4; $i++)
	{
		push @array, readFloat($rawdata, $pointer);
	}
	$_[1] = $pointer;
	return @array;
}

sub readAttachmentRegion
{
	my ($rawdata, $pointer) = @_;
	my %attachdata;
	my $path = readString($rawdata, $pointer);
	if ($path)
	{
		$attachdata{'path'} = $path;
	}
	$attachdata{'x'} = readFloat($rawdata, $pointer);
	$attachdata{'y'} = readFloat($rawdata, $pointer);
	$attachdata{'scaleX'} = readFloat($rawdata, $pointer);
	$attachdata{'scaleY'} = readFloat($rawdata, $pointer);
	$attachdata{'rotation'} = readFloat($rawdata, $pointer);
	$attachdata{'width'} = readFloat($rawdata, $pointer);
	$attachdata{'height'} = readFloat($rawdata, $pointer);
	$attachdata{'color'} = readColor($rawdata, $pointer);
	$_[1] = $pointer;
	return %attachdata;
}

sub readAttachmentMesh
{
	my ($rawdata, $pointer, $nonessential) = @_;
	my %attachdata;
	my $path = readString($rawdata, $pointer);
	if ($path)
	{
		$attachdata{'path'} = $path;
	}
	$attachdata{'color'} = readColor($rawdata, $pointer);
	my $vertexcount = readVarint($rawdata, $pointer);
	my @uvs = readFloatArray($rawdata, $pointer, $vertexcount * 2);
	$attachdata{'uvs'} = \@uvs;
	my @triangles = readShortArray($rawdata, $pointer);
	$attachdata{'triangles'} = \@triangles;
	my @vertices = readFloatArray($rawdata, $pointer, $vertexcount * 2);
	$attachdata{'vertices'} = \@vertices;
	$attachdata{'hull'} = readVarint($rawdata, $pointer);
	if ($nonessential)
	{
		my @edges = readShortArray($rawdata, $pointer);
		$attachdata{'edges'} = \@edges;
		$attachdata{'width'} = readFloat($rawdata, $pointer);
		$attachdata{'height'} = readFloat($rawdata, $pointer);
	}
	$_[1] = $pointer;
	return %attachdata;
}

sub readAttachmentWeightedMesh
{
	my ($rawdata, $pointer, $nonessential) = @_;
	my %attachdata;
	my $path = readString($rawdata, $pointer);
	if ($path)
	{
		$attachdata{'path'} = $path;
	}
	$attachdata{'color'} = readColor($rawdata, $pointer);
	my $vertexcount = readVarint($rawdata, $pointer);
	my @uvs = readFloatArray($rawdata, $pointer, $vertexcount * 2);
	$attachdata{'uvs'} = \@uvs;
	my @triangles = readShortArray($rawdata, $pointer);
	$attachdata{'triangles'} = \@triangles;
	my @vertices;
	for (my $i = 0; $i < $vertexcount; $i++)
	{
		my $bonecount = readFloat($rawdata, $pointer);
		push @vertices, $bonecount;
		for (my $j = 0; $j < $bonecount; $j++)
		{
			push @vertices, readFloat($rawdata, $pointer);
			push @vertices, readFloat($rawdata, $pointer);
			push @vertices, readFloat($rawdata, $pointer);
			push @vertices, readFloat($rawdata, $pointer);
		}
	}
	$attachdata{'vertices'} = \@vertices;
	$attachdata{'hull'} = readVarint($rawdata, $pointer);
	if ($nonessential)
	{
		my @edges = readShortArray($rawdata, $pointer);
		$attachdata{'edges'} = \@edges;
		$attachdata{'width'} = readFloat($rawdata, $pointer);
		$attachdata{'height'} = readFloat($rawdata, $pointer);
	}
	$_[1] = $pointer;
	return %attachdata;
}

sub readSkin
{
	my ($rawdata, $pointer, $slotref, $nonessential) = @_;
	my @slotname = @{$slotref};
	my %skin;
	my $slotcount = readVarint($rawdata, $pointer);
	for (my $slotid = 0; $slotid < $slotcount; $slotid++)
	{
		my %slots;
		my $slotindex = readVarint($rawdata, $pointer);
		my $attachcount = readVarint($rawdata, $pointer);
		for (my $attachid = 0; $attachid < $attachcount; $attachid++)
		{
			my %attachdata;
			my $attachname = readString($rawdata, $pointer);
			my $attachrealname = readString($rawdata, $pointer);
			my $type = readByte($rawdata, $pointer);
			if ($type == 0)
			{
				%attachdata = readAttachmentRegion($rawdata, $pointer);
				$attachdata{'type'} = 'region';
			}
			elsif ($type == 1)
			{
				die("TODO: Bounding Box attachment type.\n");
			}
			elsif ($type == 2)
			{
				%attachdata = readAttachmentMesh($rawdata, $pointer, $nonessential);
				$attachdata{'type'} = 'mesh';
			}
			elsif ($type == 3)
			{
				%attachdata = readAttachmentWeightedMesh($rawdata, $pointer, $nonessential);
				$attachdata{'type'} = 'mesh';
			}
			elsif ($type == 4)
			{
				die("TODO: Linked Mesh attachment type.\n");
			}
			elsif ($type == 5)
			{
				die("TODO: Weighted Linked Mesh attachment type.\n");
			}
			else
			{
				die("Invalid attachment type.\n");
			}
			if ($attachrealname)
			{
				$attachdata{'name'} = $attachrealname;
			}
			$slots{$attachname} = \%attachdata;
		}
		$skin{$slotname[$slotindex]} = \%slots;
	}
	$_[1] = $pointer;
	return %skin;
}

sub readAnimation
{
	my ($rawdata, $pointer, $slotref, $boneref, $skinref) = @_;
	my @slotname = @{$slotref};
	my @bonename = @{$boneref};
	my @skinname = @{$skinref};
	my %animation;
	my %slots;
	my %bones;
	my %deform;
	my @draworder;

	# Slot timelines.
	my $num = readVarint($rawdata, $pointer);
	if ($num > 0)
	{
		for (my $i = 0; $i < $num; $i++)
		{
			my %slottype;
			my $slotindex = readVarint($rawdata, $pointer);
			my $count = readVarint($rawdata, $pointer);
			for (my $j = 0; $j < $count; $j++)
			{
				my $type = readByte($rawdata, $pointer);
				my $framecount = readVarint($rawdata, $pointer);
				if ($type == 3)
				{
					my @slotdata;
					for (my $k = 0; $k < $framecount; $k++)
					{
						my %framedata;
						$framedata{'time'} = readFloat($rawdata, $pointer);
						$framedata{'name'} = readString($rawdata, $pointer);
						push @slotdata, \%framedata;
					}
					$slottype{'attachment'} = \@slotdata;
				}
				elsif ($type == 4)
				{
					my @slotdata;
					for (my $k = 0; $k < $framecount; $k++)
					{
						my %framedata;
						$framedata{'time'} = readFloat($rawdata, $pointer);
						$framedata{'color'} = readColor($rawdata, $pointer);
						if ($k < $framecount - 1)
						{
							my $curvetype = readCurveType($rawdata, $pointer);
							if ($curvetype eq 'bezier')
							{
								my @curve = readCurve($rawdata, $pointer);
								$framedata{'curve'} = \@curve;
							}
							else
							{
								$framedata{'curve'} = $curvetype;
							}
						}
						push @slotdata, \%framedata;
					}
					$slottype{'color'} = \@slotdata;
				}
				else
				{
					die("Invalid timeline type.\n");
				}
			}
			$slots{$slotname[$slotindex]} = \%slottype;
		}
		$animation{'slots'} = \%slots;
	}

	# Bone timelines.
	$num = readVarint($rawdata, $pointer);
	if ($num > 0)
	{
		for (my $i = 0; $i < $num; $i++)
		{
			my %bonetype;
			my $boneindex = readVarint($rawdata, $pointer);
			my $count = readVarint($rawdata, $pointer);
			for (my $j = 0; $j < $count; $j++)
			{
				my $type = readByte($rawdata, $pointer);
				my $framecount = readVarint($rawdata, $pointer);
				if (($type == 0) || ($type == 2))
				{
					my @bonedata;
					for (my $k = 0; $k < $framecount; $k++)
					{
						my %framedata;
						
						$framedata{'time'} = readFloat($rawdata, $pointer);
						$framedata{'x'} = readFloat($rawdata, $pointer);
						$framedata{'y'} = readFloat($rawdata, $pointer);
						if ($k < $framecount - 1)
						{
							my $curvetype = readCurveType($rawdata, $pointer);
							if ($curvetype eq 'bezier')
							{
								my @curve = readCurve($rawdata, $pointer);
								$framedata{'curve'} = \@curve;
							}
							else
							{
								$framedata{'curve'} = $curvetype;
							}
						}
						push @bonedata, \%framedata;
					}
					if ($type == 0)
					{
						$bonetype{'scale'} = \@bonedata;
					}
					else
					{
						$bonetype{'translate'} = \@bonedata;
					}
				}
				elsif ($type == 1)
				{
					my @bonedata;
					for (my $k = 0; $k < $framecount; $k++)
					{
						my %framedata;
						$framedata{'time'} = readFloat($rawdata, $pointer);
						$framedata{'angle'} = readFloat($rawdata, $pointer);
						if ($k < $framecount - 1)
						{
							my $curvetype = readCurveType($rawdata, $pointer);
							if ($curvetype eq 'bezier')
							{
								my @curve = readCurve($rawdata, $pointer);
								$framedata{'curve'} = \@curve;
							}
							else
							{
								$framedata{'curve'} = $curvetype;
							}
						}
						push @bonedata, \%framedata;
					}
					$bonetype{'rotate'} = \@bonedata;
				}
				else
				{
					die("Invalid timeline type $type.\n");
				}
			}
			$bones{$bonename[$boneindex]} = \%bonetype;
		}
		$animation{'bones'} = \%bones;
	}

	# IK timelines.
	$num = readVarint($rawdata, $pointer);
	if ($num > 0)
	{
		die("TODO: IK timelines.\n");
	}

	# Deform timelines.
	$num = readVarint($rawdata, $pointer);
	if ($num > 0)
	{
		for (my $i = 0; $i < $num; $i++)
		{
			my %skindata;
			my $skinindex = readVarint($rawdata, $pointer);
			my $count = readVarint($rawdata, $pointer);
			for (my $j = 0; $j < $count; $j++)
			{
				my %slotdata;
				my $slotindex = readVarint($rawdata, $pointer);
				my $count = readVarint($rawdata, $pointer);
				for (my $jj = 0; $jj < $count; $jj++)
				{
					my @meshdata;
					my $meshname = readString($rawdata, $pointer);
					my $framecount = readVarint($rawdata, $pointer);
					for (my $k = 0; $k < $framecount; $k++)
					{
						my %framedata;
						$framedata{'time'} = readFloat($rawdata, $pointer);
						my $end = readVarint($rawdata, $pointer);
						unless ($end == 0)
						{
							my @vertices;
							my $start = readVarint($rawdata, $pointer);
							$end += $start;
							for (my $v = $start; $v < $end; $v++)
							{
								push @vertices, readFloat($rawdata, $pointer);
							}
							$framedata{'offset'} = $start;
							$framedata{'vertices'} = \@vertices;
						}
						if ($k < $framecount - 1)
						{
							my $curvetype = readCurveType($rawdata, $pointer);
							if ($curvetype eq 'bezier')
							{
								my @curve = readCurve($rawdata, $pointer);
								$framedata{'curve'} = \@curve;
							}
							else
							{
								$framedata{'curve'} = $curvetype;
							}
						}
						push @meshdata, \%framedata;
					}
					$slotdata{$meshname} = \@meshdata;
				}
				$skindata{$slotname[$slotindex]} = \%slotdata;
			}
			$deform{$skinname[$skinindex]} = \%skindata;
		}
		#$animation{'deform'} = \%deform;
	}

	# Draw order timeline.
	$num = readVarint($rawdata, $pointer);
	if ($num > 0)
	{
		for (my $i = 0; $i < $num; $i++)
		{
			my %drawdata;
			my @offsets;
			$drawdata{'time'} = readFloat($rawdata, $pointer);
			my $offset = readVarint($rawdata, $pointer);
			for (my $ii = 0; $ii < $offset; $ii++)
			{
				my %offdata;
				my $slotindex = readVarint($rawdata, $pointer);
				my $draworder = readVarint($rawdata, $pointer);
				$offdata{'slot'} = $slotname[$slotindex];
				$offdata{'offset'} = $draworder;
				push @offsets, \%offdata;
			}
			$drawdata{'offsets'} = \@offsets;
			push @draworder, \%drawdata;
		}
		$animation{'draworder'} = \@draworder;
	}

	# Events timeline.
	$num = readVarint($rawdata, $pointer);
	if ($num > 0)
	{
		die("TODO: Events timeline.\n");
	}
	
	$_[1] = $pointer;
	return %animation;
}
