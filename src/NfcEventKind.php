<?php
declare(strict_types=1);namespace Pam\Native\Nfc;enum NfcEventKind:int{case TagDiscovered=1;case WriteCompleted=2;case Cancelled=3;case Error=4;}
