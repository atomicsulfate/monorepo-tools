<?php

namespace SS6\ShopBundle\Model\Administrator\Exception;

use Exception;
use SS6\ShopBundle\Component\Debug;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class AdministratorNotFoundException extends NotFoundHttpException implements AdministratorException {

	/**
	 * @param mixed $criteria
	 * @param \Exception $prevoious
	 */
	public function __construct($criteria, Exception $prevoious = null) {
		parent::__construct('Administrator not found by criteria '. Debug::export($criteria), $previous, 0);
	}
}
